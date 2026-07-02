#!/usr/bin/env python3
"""Generate a Tinnitus-Protocol test-data JSON file.

Layout mirrors ExportService.exportJson and adds a ``triggerKeys`` array
per entry so a future import path can pick tags up.

Example:
    python3 scripts/generate_testdata.py
    python3 scripts/generate_testdata.py --days 30 --loud-max 10 --seed 42
"""

from __future__ import annotations

import argparse
import json
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path

PREDEFINED_TRIGGER_KEYS = [
    "stress",
    "loudSound",
    "caffeine",
    "alcohol",
    "lackOfSleep",
    "weather",
    "screenTime",
    "exercise",
    "medication",
    "headache",
]

TIME_WINDOWS = {
    "morgens": (time(7, 0), time(9, 59)),
    "mittags": (time(12, 0), time(13, 59)),
    "abends":  (time(18, 0), time(20, 59)),
    "nachts":  (time(22, 0), time(23, 59)),
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--days", type=int, default=90, help="days back from yesterday (default: 90)")
    p.add_argument("--loud-min", type=int, default=2, help="min loudness 0-10 (default: 2)")
    p.add_argument("--loud-max", type=int, default=8, help="max loudness 0-10 (default: 8)")
    p.add_argument("--distress-min", type=int, default=2, help="min distress 0-10 (default: 2)")
    p.add_argument("--distress-max", type=int, default=7, help="max distress 0-10 (default: 7)")
    p.add_argument("--sleep-min", type=int, default=3, help="min sleep quality 0-10 (default: 3)")
    p.add_argument("--sleep-max", type=int, default=8, help="max sleep quality 0-10 (default: 8)")
    p.add_argument("--output", type=Path, default=Path("testdata.json"), help="output path (default: testdata.json)")
    p.add_argument("--seed", type=int, default=None, help="RNG seed for reproducible runs")
    return p.parse_args()


def validate(args: argparse.Namespace) -> None:
    checks = [
        ("loudness", args.loud_min, args.loud_max),
        ("distress", args.distress_min, args.distress_max),
        ("sleep",    args.sleep_min, args.sleep_max),
    ]
    for name, lo, hi in checks:
        if lo > hi:
            raise SystemExit(f"{name}: min ({lo}) must be <= max ({hi})")
        if lo < 0 or hi > 10:
            raise SystemExit(f"{name}: values must stay within 0-10 (got {lo}-{hi})")
    if args.days < 1:
        raise SystemExit("--days must be >= 1")


def random_time(window: tuple[time, time]) -> time:
    start, end = window
    start_secs = start.hour * 3600 + start.minute * 60
    end_secs   = end.hour   * 3600 + end.minute   * 60 + 59
    secs = random.randint(start_secs, end_secs)
    return time(secs // 3600, (secs // 60) % 60, secs % 60)


def sample_triggers() -> list[str]:
    n = random.randint(0, 4)
    if n == 0:
        return []
    return random.sample(PREDEFINED_TRIGGER_KEYS, n)


def build_payload(args: argparse.Namespace) -> dict:
    entries: list[dict] = []
    sleep:   list[dict] = []
    yesterday = date.today() - timedelta(days=1)

    for offset in range(args.days):
        day = yesterday - timedelta(days=offset)

        for window in TIME_WINDOWS.values():
            ts = datetime.combine(day, random_time(window))
            entries.append({
                "timestamp":   ts.isoformat(timespec="seconds"),
                "loudness":    random.randint(args.loud_min, args.loud_max),
                "distress":    random.randint(args.distress_min, args.distress_max),
                "notes":       None,
                "triggerKeys": sample_triggers(),
            })

        sleep.append({
            "date":    day.isoformat(),
            "quality": random.randint(args.sleep_min, args.sleep_max),
            "notes":   None,
        })

    entries.sort(key=lambda e: e["timestamp"])
    sleep.sort(key=lambda s: s["date"])
    return {"entries": entries, "sleep": sleep}


def main() -> None:
    args = parse_args()
    validate(args)
    if args.seed is not None:
        random.seed(args.seed)

    payload = build_payload(args)
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    print(f"wrote {args.output}: {len(payload['entries'])} entries, {len(payload['sleep'])} sleep logs")


if __name__ == "__main__":
    main()
