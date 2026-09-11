#!/usr/bin/env python3
"""Fetch configured Google Calendar iCal feeds and write a normalized event
cache for the clock panel to read. Read-only: never writes back to Google.

Run with the venv interpreter at ~/.local/state/omarchy/calendar/venv/bin/python
(created once with `uv venv` + `uv pip install icalendar recurring-ical-events`),
never with a bare `python3` — which interpreter that resolves to depends on
$PATH and this must not be ambiguous.
"""

import argparse
import datetime
import hashlib
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request

import icalendar
import recurring_ical_events

DEFAULT_CONFIG = os.path.expanduser("~/.local/state/omarchy/calendars.json")
DEFAULT_OUT = os.path.expanduser("~/.local/state/omarchy/calendar-cache.json")
FETCH_TIMEOUT_SECONDS = 15


def load_config(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def fetch_ics(url):
    req = urllib.request.Request(url, headers={"User-Agent": "omarchy-clock-calendar/1.0"})
    with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT_SECONDS) as resp:
        return resp.read()


def day_key(dt):
    return dt.strftime("%Y-%m-%d")


def to_local(dt):
    """Normalize a date or datetime to a timezone-aware local datetime.
    All-day events arrive as bare `date` objects; give them midnight local."""
    if isinstance(dt, datetime.datetime):
        if dt.tzinfo is None:
            dt = dt.astimezone()
        return dt.astimezone()
    # datetime.date (all-day)
    return datetime.datetime(dt.year, dt.month, dt.day).astimezone()


def stable_id(calendar_name, uid, start_iso):
    return hashlib.sha1(f"{calendar_name}\x1f{uid}\x1f{start_iso}".encode("utf-8")).hexdigest()[:16]


def collect_events(calendar_name, color, ics_bytes, window_start, window_end):
    cal = icalendar.Calendar.from_ical(ics_bytes)
    occurrences = recurring_ical_events.of(cal).between(window_start, window_end)

    events = []
    for component in occurrences:
        status = str(component.get("STATUS", "")).upper()
        if status == "CANCELLED":
            continue

        raw_start = component["DTSTART"].dt
        all_day = not isinstance(raw_start, datetime.datetime)

        start_local = to_local(raw_start)
        if "DTEND" in component:
            raw_end = component["DTEND"].dt
        else:
            raw_end = raw_start
        end_local = to_local(raw_end)

        # ICS DTEND is exclusive for VALUE=DATE all-day events: a one-day
        # event has DTEND the *next* day. Subtract a day so a single-day
        # all-day event does not appear to span two days.
        end_day_dt = end_local
        if all_day and end_local > start_local:
            end_day_dt = end_local - datetime.timedelta(days=1)

        start_iso = start_local.isoformat()
        uid = str(component.get("UID", ""))

        events.append({
            "id": stable_id(calendar_name, uid, start_iso),
            "calendar": calendar_name,
            "color": color,
            "title": str(component.get("SUMMARY", "")).strip() or "(untitled)",
            "location": str(component.get("LOCATION", "")).strip(),
            "allDay": all_day,
            "start": start_iso,
            "end": end_local.isoformat(),
            "startDay": day_key(start_local),
            "endDay": day_key(end_day_dt),
        })

    return events


def build_by_day(events):
    by_day = {}
    for index, event in enumerate(events):
        start = datetime.date.fromisoformat(event["startDay"])
        end = datetime.date.fromisoformat(event["endDay"])
        # Multi-day events (all-day spans, or a timed event that crosses
        # midnight) get an entry on every day they touch, capped generously
        # against a malformed feed claiming a years-long span.
        day = start
        guard = 0
        while day <= end and guard < 400:
            by_day.setdefault(day.isoformat(), []).append(index)
            day += datetime.timedelta(days=1)
            guard += 1
    return by_day


def atomic_write_json(path, data):
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=directory, prefix=".calendar-cache-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.chmod(tmp_path, 0o600)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--out", default=DEFAULT_OUT)
    args = parser.parse_args()

    config = load_config(args.config)
    if config is None:
        # No calendars configured yet: silent no-op, not an error.
        return 0

    calendars = config.get("calendars", [])
    days_back = int(config.get("windowDaysBack", 31))
    days_forward = int(config.get("windowDaysForward", 180))

    now = datetime.datetime.now().astimezone()
    window_start = now - datetime.timedelta(days=days_back)
    window_end = now + datetime.timedelta(days=days_forward)

    all_events = []
    calendar_status = []
    any_ok = False

    for entry in calendars:
        name = str(entry.get("name", "Calendar"))
        color = str(entry.get("color", "#7aa2f7"))
        url = entry.get("url", "")
        try:
            ics_bytes = fetch_ics(url)
            events = collect_events(name, color, ics_bytes, window_start, window_end)
            all_events.extend(events)
            calendar_status.append({"name": name, "color": color, "ok": True, "error": None})
            any_ok = True
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as exc:
            calendar_status.append({"name": name, "color": color, "ok": False, "error": str(exc)[:200]})

    if not calendars:
        any_ok = True  # nothing to fail; write an empty-but-valid cache

    if not any_ok:
        # Every configured calendar failed: leave the existing cache exactly
        # as it is rather than blanking a good agenda over a dead network.
        sys.stderr.write("all calendars failed to sync; cache left untouched\n")
        return 1

    all_events.sort(key=lambda e: (e["startDay"], e["allDay"] is False, e["start"]))

    cache = {
        "generatedAt": now.isoformat(),
        "timezone": str(now.tzinfo),
        "calendars": calendar_status,
        "events": all_events,
        "byDay": build_by_day(all_events),
    }

    atomic_write_json(args.out, cache)
    return 0


if __name__ == "__main__":
    sys.exit(main())
