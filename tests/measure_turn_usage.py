#!/usr/bin/env python3
"""Measure usage-bearing model calls over selected complete turns of exact desktop rollouts.

Cache ratio is the sum of cached input divided by the sum of input tokens.
A conflict prevents totals for the affected metrics and yields a nonzero exit status.
"""

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
USAGE_TOTALS = (*COUNTS, "uncachedInputTokens", "modelRequests")
UNKNOWN = "unknown"


def token_counts(data, *, rollout=False):
    if not isinstance(data, dict):
        return {}
    return {key: count for key, wire_key in FIELDS.items()
            if type(count := data.get(wire_key if rollout else key)) is int and count >= 0}


def summarize_usage(snapshots, baseline):
    """Subtract cumulative totals and verify each increment against its last-call tally."""
    previous = baseline
    requests = 0
    seen_updates = 0
    requests_known = True
    invalid_fields = set()
    previous_last = {}
    for total, last in snapshots:
        seen_updates += 1
        if total and total == previous:
            if any(previous_last[key] != last[key] for key in previous_last.keys() & last.keys()):
                requests_known = False
            continue
        delta = {key: value - previous[key] for key, value in total.items() if key in previous}
        invalid_fields.update(key for key, value in delta.items() if value < 0)
        if (not all(key in delta and delta[key] == last.get(key) for key in COUNTS)
                or any(key in last and last[key] != value for key, value in delta.items())):
            requests_known = False
        else:
            requests += 1
        previous = total
        previous_last = last

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


def first_count_usage(snapshots, baseline):
    for total, last in snapshots:
        if total == baseline:
            continue
        if all(key in total and key in baseline and last.get(key) == total[key] - baseline[key]
               for key in COUNTS):
            return {key: last[key] for key in COUNTS}
        break
    return UNKNOWN


def response_usage_check(records, result):
    """Compare summed unique responses, their reported turn total, and token_count."""
    if not records:
        return "unavailable", None
    _, turn_total = records[-1]
    sums = {key: sum(usage.get(key, 0) for usage, _ in records) for key in COUNTS}
    requests = result["modelRequests"]
    known = {key: result[key] for key in COUNTS if result[key] != UNKNOWN}
    if (any(sums[key] > value for key, value in known.items())
            or any(key in turn_total and sums[key] > turn_total[key] for key in COUNTS)
            or (requests != UNKNOWN and len(records) > requests)
            or any(usage.get("cachedInputTokens", 0) > usage["inputTokens"]
                   for usage, _ in records if "inputTokens" in usage)):
        return "conflict", None
    if requests == len(records) and any(key in turn_total and value != turn_total[key]
                                        for key, value in known.items()):
        return "conflict", None
    if (any(not all(key in usage for key in COUNTS) for usage, _ in records)
            or not all(key in turn_total for key in COUNTS)):
        return "incomplete", None
    first = result["firstUsage"]
    if requests == len(records) and first != UNKNOWN and any(records[0][0][key] != first[key] for key in COUNTS):
        return "conflict", None
    if any(sums[key] < turn_total[key] for key in COUNTS):
        return ("conflict" if requests == len(records) else "incomplete"), None
    if any(sums[key] < value for key, value in known.items()):
        return "incomplete", None
    if requests != UNKNOWN and len(records) < requests:
        return "conflict", None
    if not known:
        return "response-only", sums
    if len(known) < len(COUNTS) or requests == UNKNOWN:
        return "partial-match", sums
    return "matched", sums


def add_response_usage(turns, responses, conflicts, invalid_responses):
    for result in turns:
        turn_id = result["turnId"]
        records = list(responses.get(turn_id, {}).values())
        status, sums = response_usage_check(records, result)
        if turn_id in conflicts:
            status = "conflict"
        elif status != "conflict" and (turn_id in invalid_responses or
                (status == "unavailable" and (responses or invalid_responses))):
            status = "incomplete"
        result["responseUsageCheck"] = status
        if status == "conflict":
            result.update(dict.fromkeys(USAGE_TOTALS, UNKNOWN), firstUsage=UNKNOWN)
        elif sums is not None and status != "incomplete":
            result.update(sums, modelRequests=len(records),
                          uncachedInputTokens=sums["inputTokens"] - sums["cachedInputTokens"])
            result["firstUsage"] = {key: records[0][0][key] for key in COUNTS}


def aggregate_usage(turns):
    result = {
        key: sum(row[key] for row in turns) if all(row[key] != UNKNOWN for row in turns) else UNKNOWN
        for key in (*USAGE_TOTALS, "elapsedSeconds")
    }
    if result["elapsedSeconds"] != UNKNOWN:
        result["elapsedSeconds"] = round(result["elapsedSeconds"], 3)
    input_tokens, cached_tokens = result["inputTokens"], result["cachedInputTokens"]
    result["cachedInputRatio"] = (cached_tokens / input_tokens
                                  if input_tokens not in (UNKNOWN, 0) and cached_tokens != UNKNOWN else UNKNOWN)
    result["contextCompacted"] = any(row["contextCompacted"] for row in turns)
    return result


def merge_response_readings(previous, new):
    if any(old[key] != current[key] for old, current in zip(previous, new) for key in old.keys() & current.keys()):
        return None
    return tuple(old | current for old, current in zip(previous, new))


def rollout_usage(path, thread_id, count, *, from_turn=1):
    if not 1 <= from_turn <= count:
        raise ValueError("Turn range must satisfy 1 <= from_turn <= turns")
    turns = []
    baseline = dict.fromkeys(FIELDS, 0)
    snapshots = []
    responses = {}
    response_turns = {}
    conflicts = set()
    invalid_responses = set()
    turn_id = None
    started = None
    compacted = False
    with path.open(encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                raise ValueError(f"Invalid rollout JSON on line {line_number}") from None
            if line_number == 1 and (record.get("type") != "session_meta"
                    or record.get("payload", {}).get("id") != thread_id):
                raise ValueError("Rollout metadata does not match the requested thread")
            event = record.get("payload", {})
            record_type = record.get("type")
            if record_type == "token_usage_record":
                record_thread = event.get("thread_id")
                record_turn = event.get("turn_id")
                if turn_id is None or (record_thread, record_turn) not in (
                        (thread_id, turn_id), (thread_id, None), (None, turn_id)):
                    continue
                response_id = event.get("response_id")
                if record_thread is None or record_turn is None or not isinstance(response_id, str) or not response_id:
                    invalid_responses.add(turn_id)
                    continue
                owner = response_turns.setdefault(response_id, turn_id)
                if owner != turn_id:
                    conflicts.update((owner, turn_id))
                    continue
                reading = (token_counts(event.get("usage") or {}, rollout=True),
                           token_counts(event.get("turn_token_usage") or {}, rollout=True))
                active = responses.setdefault(turn_id, {})
                merged = merge_response_readings(active.get(response_id, ({}, {})), reading)
                if merged is None:
                    conflicts.add(turn_id)
                else:
                    active[response_id] = merged
                continue
            if record_type == "compacted" and turn_id is not None:
                compacted = True
            if record_type != "event_msg":
                continue
            kind = event.get("type")
            if kind == "task_started":
                if turn_id is not None:
                    raise ValueError("Another turn started before the measured turn completed")
                turn_id = event.get("turn_id")
                if not turn_id:
                    raise ValueError("Turn start has no turn ID")
                started = timestamp(record)
                compacted = False
            elif kind == "context_compacted" and turn_id is not None:
                compacted = True
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
                turns.append({"turnId": turn_id, "turnNumber": len(turns) + 1, **result,
                              "firstUsage": first_count_usage(snapshots, baseline),
                              "contextCompacted": compacted})
                if len(turns) == count:
                    add_response_usage(turns, responses, conflicts, invalid_responses)
                    selected = turns[from_turn - 1:]
                    return {"threadId": thread_id, "turns": selected, "totals": aggregate_usage(selected)}
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
    parser.add_argument("--from-turn", type=int, default=1, help="include turns from this one-based number")
    parser.add_argument("--turns", type=int, default=1, help="include turns through this one-based number")
    parser.add_argument("thread_id", nargs="+", type=UUID)
    args = parser.parse_args()
    if not 1 <= args.from_turn <= args.turns:
        parser.error("turn range must satisfy 1 <= --from-turn <= --turns")
    failed = False
    for thread_id in map(str, args.thread_id):
        try:
            result = rollout_usage(find_rollout(args.sessions, args.date, thread_id), thread_id, args.turns,
                                   from_turn=args.from_turn)
            failed |= any(row["responseUsageCheck"] == "conflict" for row in result["turns"])
        except (OSError, ValueError) as error:
            result = {"threadId": thread_id, "error": str(error)}
            failed = True
        print(json.dumps(result), flush=True)
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
