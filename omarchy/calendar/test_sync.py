"""Unit tests for sync.py. Run: python3 -m unittest omarchy/calendar/test_sync.py"""

import datetime as dt
import importlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from zoneinfo import ZoneInfo

HERE = Path(__file__).resolve().parent
TMP = tempfile.mkdtemp(prefix="toolbox-calendar-test.")


def tearDownModule():
    shutil.rmtree(TMP, ignore_errors=True)


os.environ["TOOLBOX_CALENDAR_CONFIG"] = str(Path(TMP) / "calendars.conf")
os.environ["TOOLBOX_CALENDAR_STATE"] = str(Path(TMP) / "state")
sys.path.insert(0, str(HERE))
sync = importlib.import_module("sync")

SP = ZoneInfo("America/Sao_Paulo")
NY = ZoneInfo("America/New_York")


def feed(*events, name="Work"):
    body = "\r\n".join(events)
    return f"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nX-WR-CALNAME:{name}\r\n{body}\r\nEND:VCALENDAR\r\n"


def vevent(*lines):
    return "\r\n".join(["BEGIN:VEVENT", *lines, "END:VEVENT"])


def expand(text, zone=SP, start=dt.datetime(2026, 9, 1), days=60):
    window_start = start.replace(tzinfo=zone)
    return sync.expand_feed(text, "", window_start, window_start + dt.timedelta(days=days), zone)[1]


def starts(events):
    return [e["start"] for e in events]


class ParsingTest(unittest.TestCase):
    def test_single_timed_event_with_tzid_and_folded_summary(self):
        events = expand(feed(vevent(
            "UID:a", "DTSTART;TZID=America/Sao_Paulo:20260916T140000",
            "DTEND;TZID=America/Sao_Paulo:20260916T150000", "SUMMARY:Stand", " up\\, daily",
        )))
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["title"], "Standup, daily")
        self.assertEqual(events[0]["start"], "2026-09-16T14:00:00-03:00")
        self.assertEqual(events[0]["end"], "2026-09-16T15:00:00-03:00")
        self.assertFalse(events[0]["allDay"])
        self.assertEqual(events[0]["calendar"], "Work")

    def test_utc_event_is_converted_to_local_time(self):
        events = expand(feed(vevent("UID:b", "DTSTART:20260916T170000Z", "DURATION:PT30M", "SUMMARY:Call")))
        self.assertEqual(starts(events), ["2026-09-16T14:00:00-03:00"])
        self.assertEqual(events[0]["end"], "2026-09-16T14:30:00-03:00")

    def test_all_day_event_keeps_exclusive_end_date(self):
        events = expand(feed(vevent("UID:c", "DTSTART;VALUE=DATE:20260920", "DTEND;VALUE=DATE:20260922", "SUMMARY:Trip")))
        self.assertEqual((events[0]["start"], events[0]["end"], events[0]["allDay"]), ("2026-09-20", "2026-09-22", True))

    def test_cancelled_and_out_of_window_events_are_skipped(self):
        events = expand(feed(
            vevent("UID:d", "DTSTART:20260916T170000Z", "STATUS:CANCELLED", "SUMMARY:Gone"),
            vevent("UID:e", "DTSTART:20250101T170000Z", "SUMMARY:Old"),
        ))
        self.assertEqual(events, [])

    def test_meeting_links(self):
        events = expand(feed(
            vevent("UID:f", "DTSTART:20260916T170000Z", "SUMMARY:Meet", "X-GOOGLE-CONFERENCE:https://meet.google.com/abc-defg-hij"),
            vevent("UID:g", "DTSTART:20260917T170000Z", "SUMMARY:Zoom", "DESCRIPTION:Join: https://us02web.zoom.us/j/123?pwd=x\\nThanks"),
        ))
        self.assertEqual([e["link"] for e in events], ["https://meet.google.com/abc-defg-hij", "https://us02web.zoom.us/j/123?pwd=x"])


class RecurrenceTest(unittest.TestCase):
    def test_weekly_byday_with_exdate_and_moved_instance(self):
        events = expand(feed(
            vevent("UID:w", "DTSTART;TZID=America/Sao_Paulo:20260831T093000", "DTEND;TZID=America/Sao_Paulo:20260831T094500",
                   "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20260912T025959Z", "EXDATE;TZID=America/Sao_Paulo:20260902T093000",
                   "SUMMARY:Sync"),
            vevent("UID:w", "RECURRENCE-ID;TZID=America/Sao_Paulo:20260907T093000",
                   "DTSTART;TZID=America/Sao_Paulo:20260908T110000", "DTEND;TZID=America/Sao_Paulo:20260908T111500", "SUMMARY:Sync (moved)"),
        ), start=dt.datetime(2026, 8, 30), days=30)
        self.assertEqual(sorted(starts(events)), [
            "2026-08-31T09:30:00-03:00", "2026-09-08T11:00:00-03:00", "2026-09-09T09:30:00-03:00",
        ])

    def test_count_limits_occurrences(self):
        events = expand(feed(vevent("UID:c", "DTSTART;TZID=America/Sao_Paulo:20260901T080000", "RRULE:FREQ=DAILY;COUNT=3", "SUMMARY:x")))
        self.assertEqual(len(events), 3)

    def test_monthly_last_friday_and_negative_monthday(self):
        last_friday = expand(feed(vevent("UID:m", "DTSTART;VALUE=DATE:20260925", "RRULE:FREQ=MONTHLY;BYDAY=-1FR", "SUMMARY:x")), days=90)
        self.assertEqual(starts(last_friday), ["2026-09-25", "2026-10-30", "2026-11-27"])
        month_end = expand(feed(vevent("UID:n", "DTSTART;VALUE=DATE:20260930", "RRULE:FREQ=MONTHLY;BYMONTHDAY=-1", "SUMMARY:x")), days=91)
        self.assertEqual(starts(month_end), ["2026-09-30", "2026-10-31", "2026-11-30"])

    def test_monthly_on_31st_skips_short_months(self):
        events = expand(feed(vevent("UID:o", "DTSTART;VALUE=DATE:20260831", "RRULE:FREQ=MONTHLY", "SUMMARY:x")), start=dt.datetime(2026, 8, 1), days=120)
        self.assertEqual(starts(events), ["2026-08-31", "2026-10-31"])

    def test_biweekly_interval_respects_week_start(self):
        events = expand(feed(vevent("UID:p", "DTSTART;TZID=America/Sao_Paulo:20260901T100000",
                                    "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH;WKST=SU", "SUMMARY:x")), days=30)
        self.assertEqual([s[:10] for s in starts(events)], ["2026-09-01", "2026-09-03", "2026-09-15", "2026-09-17", "2026-09-29"])

    def test_yearly_birthday_started_long_ago(self):
        events = expand(feed(vevent("UID:y", "DTSTART;VALUE=DATE:19900915", "RRULE:FREQ=YEARLY", "SUMMARY:Birthday")))
        self.assertEqual(starts(events), ["2026-09-15"])

    def test_wall_clock_time_survives_dst_change(self):
        events = expand(feed(vevent("UID:z", "DTSTART;TZID=America/New_York:20261030T090000", "RRULE:FREQ=DAILY;COUNT=4", "SUMMARY:x")),
                        zone=NY, start=dt.datetime(2026, 10, 29), days=10)
        self.assertEqual(starts(events), [
            "2026-10-30T09:00:00-04:00", "2026-10-31T09:00:00-04:00", "2026-11-01T09:00:00-05:00", "2026-11-02T09:00:00-05:00",
        ])


class SyncTest(unittest.TestCase):
    def setUp(self):
        Path(os.environ["TOOLBOX_CALENDAR_CONFIG"]).write_text(
            "# comment\nWork = https://example.test/work.ics\nhttps://example.test/home.ics\n", encoding="utf-8")
        sync.EVENTS_FILE.unlink(missing_ok=True)

    def test_config_parsing_and_masking(self):
        self.assertEqual(sync.read_calendars(), [
            {"name": "Work", "url": "https://example.test/work.ics"},
            {"name": "", "url": "https://example.test/home.ics"},
        ])
        self.assertNotIn("work", sync.mask_url("https://example.test/secret-token/work.ics").split("…")[0])

    def test_failed_calendar_keeps_previous_events(self):
        now = dt.datetime(2026, 9, 16, 12, tzinfo=dt.datetime.now().astimezone().tzinfo)
        good = feed(vevent("UID:h", "DTSTART;VALUE=DATE:20260917", "SUMMARY:Home thing"), name="Home")
        work = feed(vevent("UID:w", "DTSTART;VALUE=DATE:20260918", "SUMMARY:Work thing"))
        first = sync.sync(now, lambda url: work if "work" in url else good)
        self.assertEqual([e["title"] for e in first["events"]], ["Home thing", "Work thing"])
        self.assertEqual([e["calendar"] for e in first["events"]], ["Home", "Work"])
        sync.write_atomic(sync.EVENTS_FILE, first)

        def flaky(url):
            if "work" in url:
                raise urllib.error.HTTPError(url, 404, "Not Found", None, io.BytesIO())
            return good

        second = sync.sync(now, flaky)
        self.assertEqual([e["title"] for e in second["events"]], ["Home thing", "Work thing"])
        self.assertEqual(second["errors"], [{"calendar": "Work", "message": "HTTP 404 (address was reset or is wrong)"}])
        self.assertEqual(oct(sync.EVENTS_FILE.stat().st_mode & 0o777), "0o600")
        json.loads(sync.EVENTS_FILE.read_text())

    def test_rejects_plain_http(self):
        with self.assertRaises(ValueError):
            sync.fetch("http://example.test/cal.ics")


if __name__ == "__main__":
    unittest.main()
