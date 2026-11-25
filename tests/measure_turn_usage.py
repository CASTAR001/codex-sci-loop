#!/usr/bin/env python3
"""Measure usage-bearing model calls in the first N completed turns of specified desktop rollouts."""

import argparse
import json
from datetime import date, datetime
from pathlib import Path
from uuid import UUID


FIELDS = {
    "inputTokens": "input_tokens",
    "cachedInputTokens": "cached_input_tokens",
    "outputTokens": "output_tokens",
    "reasoningOutputTokens": "reasoning_output_tokens",
}
COUNTS = ("inputTokens", "cachedInputTokens", "outputTokens")
UNKNOWN = "unknown"


def token_counts(data, *, rollout=False):
    return {key: count for key, wire_key in FIELDS.items()
            if type(count := data.get(wire_key if rollout else key)) is int and count >= 0}


def summarize_usage(snapshots, baseline):
    """Subtract cumulative totals and verify each increment against its last-call tally."""
    previous = baseline
    requests = 0
    seen_updates = 0
    requests_known = True
    invalid_fields = set()
    for total, last in snapshots:
        seen_updates += 1
        if total and total == previous:
            continue
        delta = {key: value - previous[key] for key, value in total.items() if key in previous}
        invalid_fields.update(key for key, value in delta.items() if value < 0)
        if (not all(key in delta and delta[key] == last.get(key) for key in COUNTS)
                or any(key in last and last[key] != value for key, value in delta.items())):
            requests_known = False
        else:
            requests += 1
        previous = total

    totals = {key: previous[key] - baseline[key]
              if seen_updates and key in previous and key in baseline and key not in invalid_fields
              and previous[key] >= baseline[key] else UNKNOWN for key in COUNTS}
    input_tokens, cached_tokens = totals["inputTokens"], totals["cachedInputTokens"]
    totals["uncachedInputTokens"] = UNKNOWN
    if type(input_tokens) is int and type(cached_tokens) is int:
        if input_tokens >= cached_tokens:
            totals["uncachedInputTokens"] = input_tokens - cached_tokens
        else:
            totals["cachedInputTokens"] = UNKNOWN
            requests_known = False
    totals["modelRequests"] = requests if requests_known and requests else UNKNOWN
    totals["usageUpdates"] = seen_updates
    return totals


def timestamp(record):
    try:
        parsed = datetime.fromisoformat(record.get("timestamp", "").replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None
    return parsed if parsed.tzinfo is not None else None


def rollout_usage(path, thread_id, count):
    turns = []
    baseline = dict.fromkeys(FIELDS, 0)
    snapshots = []
    turn_id = None
    started = None
    with path.open(encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                raise ValueError(f"Invalid rollout JSON on line {line_number}") from None
            if line_number == 1 and (record.get("type") != "session_meta"
                    or record.get("payload", {}).get("id") != thread_id):
                raise ValueError("Rollout metadata does not match the requested thread")
            if record.get("type") != "event_msg":
                continue
            event = record.get("payload", {})
            kind = event.get("type")
            if kind == "task_started":
                if turn_id is not None:
                    raise ValueError("Another turn started before the measured turn completed")
                turn_id = event.get("turn_id")
                if not turn_id:
                    raise ValueError("Turn start has no turn ID")
                started = timestamp(record)
            elif kind == "token_count" and turn_id is not None and event.get("info") is not None:
                info = event["info"]
                snapshots.append((token_counts(info.get("total_token_usage") or {}, rollout=True),
                                  token_counts(info.get("last_token_usage") or {}, rollout=True)))
            elif kind == "task_complete" and turn_id is not None:
                if event.get("turn_id") != turn_id:
                    raise ValueError("Turn completion ID does not match its start")
                completed = timestamp(record)
                elapsed = started and completed and round((completed - started).total_seconds(), 3)
                result = summarize_usage(snapshots, baseline)
                result["elapsedSeconds"] = elapsed if elapsed is not None and elapsed >= 0 else UNKNOWN
                turns.append({"turnId": turn_id, **result})
                if len(turns) == count:
                    return {"threadId": thread_id, "turns": turns}
                baseline = snapshots[-1][0] if snapshots else {}
                snapshots.clear()
                turn_id = None
    raise ValueError(f"Expected {count} completed turns, found {len(turns)}")


def find_rollout(sessions, day, thread_id):
    directory = sessions / f"{day:%Y}" / f"{day:%m}" / f"{day:%d}"
    files = [path for path in directory.glob(f"rollout-{day}T*-{thread_id}.jsonl")
             if path.is_file() and not path.is_symlink()]
    if len(files) != 1:
        raise ValueError(f"Expected one rollout for {thread_id} on {day}, found {len(files)}")
    return files[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, type=date.fromisoformat, help="exact session directory date")
    parser.add_argument("--sessions", type=Path, default=Path.home() / ".codex" / "sessions")
    parser.add_argument("--turns", type=int, default=1, help="number of initial turns to measure")
    parser.add_argument("thread_id", nargs="+", type=UUID)
    args = parser.parse_args()
    if args.turns < 1:
        parser.error("--turns must be positive")
    failed = False
    for thread_id in map(str, args.thread_id):
        try:
            result = rollout_usage(find_rollout(args.sessions, args.date, thread_id), thread_id, args.turns)
        except (OSError, ValueError) as error:
            result = {"threadId": thread_id, "error": str(error)}
            failed = True
        print(json.dumps(result), flush=True)
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
