#!/usr/bin/env python3
"""Regression coverage for desktop rollout usage without live model requests."""

import json
import tempfile
import unittest
from pathlib import Path

from measure_turn_usage import COUNTS, FIELDS, UNKNOWN, rollout_usage


THREAD = "test-thread"


def wire(counts):
    return {FIELDS[key]: value for key, value in zip(COUNTS, counts)}


def update(total, last):
    return event("token_count", info={"total_token_usage": wire(total), "last_token_usage": wire(last)})


def event(kind, **payload):
    return {"type": "event_msg", "payload": {"type": kind, **payload}}


def response(response_id, usage, turn_total, *, thread=THREAD, turn="first"):
    return {"type": "token_usage_record", "payload": {
        "response_id": response_id, "thread_id": thread, "turn_id": turn,
        "usage": wire(usage), "turn_token_usage": wire(turn_total),
    }}


def turn(turn_id, *events):
    return [event("task_started", turn_id=turn_id), *events, event("task_complete", turn_id=turn_id)]


class RolloutUsageTests(unittest.TestCase):
    def measure(self, *records, count=1, from_turn=1):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "rollout.jsonl"
            data = [{"type": "session_meta", "payload": {"id": THREAD}}, *records]
            path.write_text("".join(json.dumps({
                "timestamp": f"2026-11-25T08:00:{i:02d}.000Z", **record,
            }) + "\n" for i, record in enumerate(data)), encoding="utf-8")
            return rollout_usage(path, THREAD, count, from_turn=from_turn)

    def test_legacy_range_baseline_weighted_cache_and_compaction(self):
        report = self.measure(
            *turn("first", update((80, 60, 8), (80, 60, 8))),
            *turn("second", update((90, 60, 9), (10, 0, 1))),
            *turn("third", event("context_compacted"), update((180, 150, 11), (90, 90, 2))),
            count=3, from_turn=2,
        )
        self.assertEqual([row["turnNumber"] for row in report["turns"]], [2, 3])
        self.assertEqual([row["responseUsageCheck"] for row in report["turns"]], ["unavailable"] * 2)
        self.assertEqual(report["turns"][0]["firstUsage"], dict(zip(COUNTS, (10, 0, 1))))
        self.assertEqual(report["totals"], dict(
            inputTokens=100, cachedInputTokens=90, uncachedInputTokens=10, outputTokens=3,
            modelRequests=2, elapsedSeconds=5.0, cachedInputRatio=0.9, contextCompacted=True,
        ))

    def test_matching_responses_ignore_foreign_and_replayed_records(self):
        first = response("r1", (10, 2, 1), (10, 2, 1))
        second = response("r2", (20, 15, 3), (20, 15, 3), turn="second")
        report = self.measure(
            *turn("first", response("r1", (10, 2), (10, 2)), first, first,
                  response("r1", (999, 0, 0), (999, 0, 0), thread="foreign"),
                  update((10, 2, 1), (10, 2, 1))),
            *turn("second", first, second, update((30, 17, 4), (20, 15, 3))),
            count=2,
        )
        self.assertEqual([row["responseUsageCheck"] for row in report["turns"]], ["matched", "matched"])
        self.assertEqual(report["totals"]["modelRequests"], 2)
        self.assertEqual(report["totals"]["inputTokens"], 30)

    def test_missing_response_fields_remain_visible(self):
        report = self.measure(*turn("first", response("r1", (10, 2), (10, 2, 1)),
                                    update((10, 2, 1), (10, 2, 1))))
        self.assertEqual(report["turns"][0]["responseUsageCheck"], "incomplete")
        self.assertEqual(report["totals"]["outputTokens"], 1)
        report = self.measure(*turn("first", response(None, (10, 2, 1), (10, 2, 1))))
        self.assertEqual(report["turns"][0]["responseUsageCheck"], "incomplete")
        self.assertEqual(report["totals"]["cachedInputRatio"], UNKNOWN)

    def test_conflicting_response_and_cross_turn_id_invalidate_totals(self):
        for records in (
            (response("r1", (10, 2, 1), (10, 2, 1)), response("r1", (11, 2, 1), (11, 2, 1))),
            (response("r1", (9, 2, 1), (9, 2, 1)),),
            (response("r1", (10, 2, 1), (11, 2, 1)),),
            (response("r1", (11, 2), (11, 2)),),
        ):
            with self.subTest(records=records):
                report = self.measure(*turn("first", *records, update((10, 2, 1), (10, 2, 1))))
                self.assertEqual(report["turns"][0]["responseUsageCheck"], "conflict")
                self.assertEqual(report["totals"]["cachedInputRatio"], UNKNOWN)
        report = self.measure(
            *turn("first", response("r1", (10, 2, 1), (10, 2, 1))),
            *turn("second", response("r1", (10, 2, 1), (10, 2, 1), turn="second")),
            count=2,
        )
        self.assertEqual([row["responseUsageCheck"] for row in report["turns"]], ["conflict", "conflict"])
        self.assertEqual(report["totals"]["modelRequests"], UNKNOWN)

    def test_missing_token_updates_recover_from_response_totals(self):
        report = self.measure(*turn("first", response("r1", (10, 2, 1), (10, 2, 1))))
        self.assertEqual(report["turns"][0]["responseUsageCheck"], "response-only")
        self.assertEqual(report["totals"]["modelRequests"], 1)
        self.assertEqual(report["totals"]["cachedInputRatio"], 0.2)


if __name__ == "__main__":
    unittest.main()
