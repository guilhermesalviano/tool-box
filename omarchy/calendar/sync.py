#!/usr/bin/env python3
"""Read-only calendar sync for the toolbox.calendar Omarchy plugin.

Downloads each iCal (ICS) address listed in the calendars file, expands the
events that fall inside a window around today, and writes them to one JSON
file the bar widget reads. Standard library only: nothing to install.

Calendars file (one per line, private: it holds secret addresses):
    ~/.config/toolbox-calendar/calendars.conf
        Personal = https://calendar.google.com/calendar/ical/.../basic.ics
        https://example.com/team.ics        # name taken from the feed

Output:
    ~/.local/state/toolbox-calendar/events.json
"""

from __future__ import annotations

import calendar as cal
import datetime as dt
import fcntl
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

HOME = Path.home()
CONFIG_FILE = Path(os.environ.get("TOOLBOX_CALENDAR_CONFIG", HOME / ".config/toolbox-calendar/calendars.conf"))
STATE_DIR = Path(os.environ.get("TOOLBOX_CALENDAR_STATE", HOME / ".local/state/toolbox-calendar"))
EVENTS_FILE = STATE_DIR / "events.json"

DAYS_BACK = 45
DAYS_AHEAD = 120
FETCH_TIMEOUT = 20
MAX_FEED_BYTES = 20 * 1024 * 1024

WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
MEETING_LINK = re.compile(
    r"https://(?:meet\.google\.com/[a-z0-9-]+|[\w.-]*zoom\.us/j/[^\s\"<>\\]+|teams\.microsoft\.com/l/meetup-join/[^\s\"<>\\]+)",
    re.IGNORECASE,
)


# --------------------------------------------------------------------------- config


def read_calendars(path: Path = CONFIG_FILE) -> list[dict]:
    """Parse `Name = URL` or bare `URL` lines. Comments start with #."""
    calendars = []
    if not path.exists():
        return calendars
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        name, url = "", line
        if "=" in line and not line.lower().startswith(("http://", "https://")):
            name, url = (part.strip() for part in line.split("=", 1))
        calendars.append({"name": name, "url": url})
    return calendars


def mask_url(url: str) -> str:
    """Enough to recognise an address without leaking its secret part."""
    match = re.match(r"(https?://[^/]+)", url)
    host = match.group(1) if match else "?"
    return f"{host}/…{url[-8:]}" if len(url) > 8 else host


# --------------------------------------------------------------------------- ICS parsing


def unfold(text: str) -> list[str]:
    lines: list[str] = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line[:1] in (" ", "\t") and lines:
            lines[-1] += line[1:]
        elif line:
            lines.append(line)
    return lines


def split_property(line: str) -> tuple[str, dict, str]:
    """`NAME;PARAM=a;PARAM2="b:c":value` -> (NAME, params, value)."""
    in_quotes = False
    for index, char in enumerate(line):
        if char == '"':
            in_quotes = not in_quotes
        elif char == ":" and not in_quotes:
            head, value = line[:index], line[index + 1 :]
            break
    else:
        return line.upper(), {}, ""
    parts = re.findall(r'(?:[^;"]|"[^"]*")+', head)
    name = parts[0].upper() if parts else ""
    params = {}
    for part in parts[1:]:
        key, _, param_value = part.partition("=")
        params[key.upper()] = param_value.strip('"')
    return name, params, value


def unescape(value: str) -> str:
    return re.sub(r"\\([\\;,nN])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), value)


def parse_components(text: str) -> tuple[dict, list[dict]]:
    """Return (calendar properties, list of VEVENT property lists)."""
    calendar_props: dict = {}
    events: list[dict] = []
    stack: list[str] = []
    current: dict | None = None
    for line in unfold(text):
        name, params, value = split_property(line)
        if name == "BEGIN":
            stack.append(value.upper())
            if value.upper() == "VEVENT":
                current = {}
            continue
        if name == "END":
            if stack and stack[-1] == "VEVENT" and current is not None:
                events.append(current)
                current = None
            if stack:
                stack.pop()
            continue
        if current is not None and stack and stack[-1] == "VEVENT":
            current.setdefault(name, []).append((params, value))
        elif stack == ["VCALENDAR"]:
            calendar_props.setdefault(name, []).append((params, value))
    return calendar_props, events


def zone_for(tzid: str | None, local_zone: dt.tzinfo) -> dt.tzinfo:
    if not tzid:
        return local_zone
    try:
        return ZoneInfo(tzid)
    except (ZoneInfoNotFoundError, ValueError):
        return local_zone


def parse_time(params: dict, value: str, local_zone: dt.tzinfo) -> dt.date | dt.datetime:
    """DATE -> date; DATE-TIME -> aware datetime (UTC, TZID, or floating as local)."""
    value = value.strip()
    if params.get("VALUE", "").upper() == "DATE" or re.fullmatch(r"\d{8}", value):
        return dt.datetime.strptime(value[:8], "%Y%m%d").date()
    utc = value.endswith("Z")
    naive = dt.datetime.strptime(value.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if utc:
        return naive.replace(tzinfo=dt.timezone.utc)
    return naive.replace(tzinfo=zone_for(params.get("TZID"), local_zone))


def parse_duration(value: str) -> dt.timedelta:
    match = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", value.strip())
    if not match:
        return dt.timedelta(0)
    sign, weeks, days, hours, minutes, seconds = match.groups()
    delta = dt.timedelta(
        weeks=int(weeks or 0), days=int(days or 0), hours=int(hours or 0), minutes=int(minutes or 0), seconds=int(seconds or 0)
    )
    return -delta if sign == "-" else delta


def first(props: dict, name: str) -> tuple[dict, str] | None:
    values = props.get(name)
    return values[0] if values else None


def text_of(props: dict, name: str) -> str:
    entry = first(props, name)
    return unescape(entry[1]).strip() if entry else ""


# --------------------------------------------------------------------------- recurrence


def parse_rrule(value: str) -> dict:
    rule: dict = {}
    for part in value.split(";"):
        key, _, part_value = part.partition("=")
        rule[key.upper()] = part_value
    return rule


def _byday(rule: dict) -> list[tuple[int | None, int]]:
    out = []
    for item in filter(None, rule.get("BYDAY", "").split(",")):
        match = re.fullmatch(r"([+-]?\d+)?([A-Z]{2})", item.strip().upper())
        if match and match.group(2) in WEEKDAYS:
            out.append((int(match.group(1)) if match.group(1) else None, WEEKDAYS[match.group(2)]))
    return out


def _ints(rule: dict, key: str) -> list[int]:
    return [int(x) for x in rule.get(key, "").split(",") if re.fullmatch(r"[+-]?\d+", x.strip())]


def _days_matching(year: int, month: int, byday: list[tuple[int | None, int]]) -> list[int]:
    """Days of a month selected by BYDAY entries like MO, 2TU, -1FR."""
    days_in_month = cal.monthrange(year, month)[1]
    selected = set()
    for ordinal, weekday in byday:
        matches = [d for d in range(1, days_in_month + 1) if dt.date(year, month, d).weekday() == weekday]
        if ordinal is None:
            selected.update(matches)
        elif 0 < ordinal <= len(matches):
            selected.add(matches[ordinal - 1])
        elif 0 < -ordinal <= len(matches):
            selected.add(matches[ordinal])
    return sorted(selected)


def _month_days(year: int, month: int, bymonthday: list[int]) -> list[int]:
    days_in_month = cal.monthrange(year, month)[1]
    out = set()
    for day in bymonthday:
        actual = day if day > 0 else days_in_month + day + 1
        if 1 <= actual <= days_in_month:
            out.add(actual)
    return sorted(out)


def _dates_for_month(year: int, month: int, rule: dict, anchor: dt.date) -> list[dt.date]:
    byday, bymonthday = _byday(rule), _ints(rule, "BYMONTHDAY")
    if byday and bymonthday:
        days = sorted(set(_days_matching(year, month, byday)) & set(_month_days(year, month, bymonthday)))
    elif byday:
        days = _days_matching(year, month, byday)
    elif bymonthday:
        days = _month_days(year, month, bymonthday)
    else:
        days = [anchor.day] if anchor.day <= cal.monthrange(year, month)[1] else []
    return [dt.date(year, month, d) for d in days]


def _apply_setpos(dates: list[dt.date], rule: dict) -> list[dt.date]:
    positions = _ints(rule, "BYSETPOS")
    if not positions:
        return dates
    picked = set()
    for pos in positions:
        if 0 < pos <= len(dates):
            picked.add(dates[pos - 1])
        elif 0 < -pos <= len(dates):
            picked.add(dates[pos])
    return sorted(picked)


def recurrence_dates(anchor: dt.date, rule: dict, until_date: dt.date | None, stop: dt.date):
    """Yield candidate dates in order, starting at the anchor's period.

    Times are handled by the caller: every occurrence keeps the start's
    wall-clock time, which is how calendar apps define recurring events.
    """
    freq = rule.get("FREQ", "").upper()
    interval = max(1, int(rule.get("INTERVAL", "1") or 1))
    bymonth = _ints(rule, "BYMONTH")
    byday = _byday(rule)
    limit = min(stop, until_date) if until_date else stop

    if freq == "DAILY":
        day = anchor
        while day <= limit:
            if (not bymonth or day.month in bymonth) and (not byday or day.weekday() in {w for _, w in byday}):
                if not _ints(rule, "BYMONTHDAY") or day.day in _month_days(day.year, day.month, _ints(rule, "BYMONTHDAY")):
                    yield day
            day += dt.timedelta(days=interval)
    elif freq == "WEEKLY":
        week_start = WEEKDAYS.get(rule.get("WKST", "MO").upper(), 0)
        period = anchor - dt.timedelta(days=(anchor.weekday() - week_start) % 7)
        weekdays = sorted({w for _, w in byday}, key=lambda w: (w - week_start) % 7) or [anchor.weekday()]
        while period <= limit:
            dates = [period + dt.timedelta(days=(w - week_start) % 7) for w in weekdays]
            for day in _apply_setpos(dates, rule):
                if not bymonth or day.month in bymonth:
                    yield day
            period += dt.timedelta(weeks=interval)
    elif freq == "MONTHLY":
        year, month = anchor.year, anchor.month
        while dt.date(year, month, 1) <= limit:
            if not bymonth or month in bymonth:
                yield from _apply_setpos(_dates_for_month(year, month, rule, anchor), rule)
            month += interval
            year, month = year + (month - 1) // 12, (month - 1) % 12 + 1
    elif freq == "YEARLY":
        year = anchor.year
        while dt.date(year, 1, 1) <= limit:
            months = bymonth or [anchor.month]
            dates: list[dt.date] = []
            for month in months:
                if byday and not bymonth and not _ints(rule, "BYMONTHDAY"):
                    # BYDAY without BYMONTH counts weekdays across the whole year.
                    for ordinal, weekday in byday:
                        matches = [dt.date(year, 1, 1) + dt.timedelta(days=i) for i in range(366 if cal.isleap(year) else 365)]
                        matches = [d for d in matches if d.weekday() == weekday]
                        if ordinal is None:
                            dates.extend(matches)
                        elif 0 < abs(ordinal) <= len(matches):
                            dates.append(matches[ordinal - 1 if ordinal > 0 else ordinal])
                    break
                dates.extend(_dates_for_month(year, month, rule, anchor))
            yield from _apply_setpos(sorted(set(dates)), rule)
            year += interval


def instance_key(value: dt.date | dt.datetime) -> str:
    if isinstance(value, dt.datetime):
        return value.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return value.isoformat()


def occurrences(start, rule: dict, exdates: set[str], window_start: dt.datetime, window_end: dt.datetime, local_zone):
    """Start values of a recurring event that begin before the window end."""
    count = int(rule["COUNT"]) if rule.get("COUNT", "").isdigit() else None
    until = None
    if rule.get("UNTIL"):
        until = parse_time({}, rule["UNTIL"], dt.timezone.utc if rule["UNTIL"].endswith("Z") else local_zone)
    is_datetime = isinstance(start, dt.datetime)
    anchor = start.date() if is_datetime else start
    until_date = None
    if until is not None:
        until_date = until.astimezone(start.tzinfo).date() if is_datetime and isinstance(until, dt.datetime) else (
            until.date() if isinstance(until, dt.datetime) else until
        )
    stop = window_end.astimezone(start.tzinfo).date() if is_datetime else window_end.date()

    emitted = 0
    for day in recurrence_dates(anchor, rule, until_date, stop):
        if day < anchor:
            continue
        value = dt.datetime.combine(day, start.timetz()) if is_datetime else day
        if is_datetime:
            value = value.replace(tzinfo=start.tzinfo)
            if until is not None and isinstance(until, dt.datetime) and value > until:
                return
        elif until is not None and day > until_date:
            return
        emitted += 1
        if count is not None and emitted > count:
            return
        if instance_key(value) not in exdates:
            yield value


# --------------------------------------------------------------------------- events


def meeting_link(props: dict) -> str:
    conference = text_of(props, "X-GOOGLE-CONFERENCE")
    if conference.startswith("https://"):
        return conference
    for field in ("LOCATION", "DESCRIPTION", "URL"):
        match = MEETING_LINK.search(text_of(props, field))
        if match:
            return match.group(0)
    return ""


def as_window_datetime(value, local_zone) -> dt.datetime:
    if isinstance(value, dt.datetime):
        return value
    return dt.datetime.combine(value, dt.time(), tzinfo=local_zone)


def expand_feed(text: str, calendar_name: str, window_start: dt.datetime, window_end: dt.datetime, local_zone) -> tuple[str, list[dict]]:
    calendar_props, raw_events = parse_components(text)
    feed_name = text_of(calendar_props, "X-WR-CALNAME")
    name = calendar_name or feed_name or "Calendar"

    overrides: dict[str, set[str]] = {}
    for props in raw_events:
        recurrence = first(props, "RECURRENCE-ID")
        if recurrence and first(props, "UID"):
            key = instance_key(parse_time(recurrence[0], recurrence[1], local_zone))
            overrides.setdefault(text_of(props, "UID"), set()).add(key)

    out: list[dict] = []
    for props in raw_events:
        start_entry = first(props, "DTSTART")
        if not start_entry or text_of(props, "STATUS").upper() == "CANCELLED":
            continue
        try:
            start = parse_time(start_entry[0], start_entry[1], local_zone)
            end_entry = first(props, "DTEND")
            if end_entry:
                end = parse_time(end_entry[0], end_entry[1], local_zone)
            elif first(props, "DURATION"):
                end = start + parse_duration(first(props, "DURATION")[1])
            else:
                end = start + (dt.timedelta(days=1) if not isinstance(start, dt.datetime) else dt.timedelta(0))
        except ValueError:
            continue
        # A date start with a datetime end (or the reverse) is malformed; treat the end as the start's kind.
        if isinstance(start, dt.datetime) != isinstance(end, dt.datetime):
            end = start + (dt.timedelta(hours=1) if isinstance(start, dt.datetime) else dt.timedelta(days=1))
        duration = end - start

        uid = text_of(props, "UID")
        rrule = first(props, "RRULE")
        if rrule and not first(props, "RECURRENCE-ID"):
            exdates = set(overrides.get(uid, set()))
            for params, value in props.get("EXDATE", []):
                for item in value.split(","):
                    if item.strip():
                        try:
                            exdates.add(instance_key(parse_time(params, item, local_zone)))
                        except ValueError:
                            pass
            starts = occurrences(start, parse_rrule(rrule[1]), exdates, window_start, window_end, local_zone)
        else:
            starts = [start]

        base = {
            "title": text_of(props, "SUMMARY") or "(No title)",
            "location": text_of(props, "LOCATION"),
            "link": meeting_link(props),
            "calendar": name,
        }
        for occurrence in starts:
            finish = occurrence + duration
            if as_window_datetime(finish, local_zone) <= window_start or as_window_datetime(occurrence, local_zone) >= window_end:
                continue
            all_day = not isinstance(occurrence, dt.datetime)
            out.append(
                dict(
                    base,
                    id=f"{uid}@{instance_key(occurrence)}",
                    allDay=all_day,
                    start=occurrence.isoformat() if all_day else occurrence.astimezone(local_zone).isoformat(),
                    end=finish.isoformat() if all_day else finish.astimezone(local_zone).isoformat(),
                )
            )
    return feed_name, out


def fetch(url: str) -> str:
    if not url.lower().startswith("https://"):
        raise ValueError("calendar addresses must start with https://")
    request = urllib.request.Request(url, headers={"User-Agent": "toolbox-calendar/1.0"})
    with urllib.request.urlopen(request, timeout=FETCH_TIMEOUT) as response:
        data = response.read(MAX_FEED_BYTES + 1)
    if len(data) > MAX_FEED_BYTES:
        raise ValueError("calendar feed is too large")
    text = data.decode("utf-8", errors="replace")
    if "BEGIN:VCALENDAR" not in text:
        raise ValueError("the address did not return an iCal calendar")
    return text


def describe_error(error: Exception) -> str:
    if isinstance(error, urllib.error.HTTPError):
        return f"HTTP {error.code}" + (" (address was reset or is wrong)" if error.code in (401, 403, 404) else "")
    if isinstance(error, urllib.error.URLError):
        return f"network error: {error.reason}"
    return str(error) or error.__class__.__name__


def sort_key(event: dict) -> tuple:
    start = event["start"]
    moment = dt.datetime.fromisoformat(start) if "T" in start else dt.datetime.fromisoformat(start + "T00:00:00")
    if moment.tzinfo is None:
        moment = moment.astimezone()
    return (moment.astimezone(dt.timezone.utc), not event["allDay"], event["title"].lower())


def sync(now: dt.datetime | None = None, fetcher=fetch) -> dict:
    local_zone = dt.datetime.now().astimezone().tzinfo
    now = now or dt.datetime.now(local_zone)
    today = dt.datetime.combine(now.date(), dt.time(), tzinfo=now.tzinfo)
    window_start = today - dt.timedelta(days=DAYS_BACK)
    window_end = today + dt.timedelta(days=DAYS_AHEAD)

    previous: dict = {}
    if EVENTS_FILE.exists():
        try:
            previous = json.loads(EVENTS_FILE.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            previous = {}

    calendars = read_calendars()
    events: list[dict] = []
    errors: list[dict] = []
    for index, entry in enumerate(calendars):
        label = entry["name"] or f"Calendar {index + 1}"
        try:
            feed_name, feed_events = expand_feed(fetcher(entry["url"]), entry["name"], window_start, window_end, local_zone)
            events.extend(feed_events)
        except Exception as error:  # noqa: BLE001 - one bad feed must not stop the others
            errors.append({"calendar": label, "message": describe_error(error)})
            # Keep what this calendar had last time rather than blanking it on a network blip.
            events.extend(e for e in previous.get("events", []) if e.get("source") == index)
            continue
        for event in feed_events:
            event["source"] = index

    events.sort(key=sort_key)
    return {
        "syncedAt": now.isoformat(timespec="seconds"),
        "calendars": len(calendars),
        "errors": errors,
        "events": events,
    }


def write_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".events.", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def main() -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    # Several bars (one per monitor) may ask for a sync at once; one is enough.
    with open(STATE_DIR / ".sync.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        payload = sync()
        write_atomic(EVENTS_FILE, payload)

    for error in payload["errors"]:
        print(f"{error['calendar']}: {error['message']}", file=sys.stderr)
    print(f"{len(payload['events'])} events from {payload['calendars'] - len(payload['errors'])}/{payload['calendars']} calendars")
    return 1 if payload["calendars"] and len(payload["errors"]) == payload["calendars"] else 0


if __name__ == "__main__":
    sys.exit(main())
