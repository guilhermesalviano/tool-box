# Calendar — Google Calendar events in the Omarchy clock

This folder is an Omarchy shell plugin, **`toolbox.calendar`**: a copy of
Omarchy's clock that also shows your calendar events.

- **Bar:** while a meeting is under way, or starts within the hour, the clock
  label adds it: `Wednesday 13:15  ·  in 45m Planning`.
- **Notifications:** 30 minutes before each timed event, a desktop
  notification shows the time, calendar and, for meetings, "click to join".
  Clicking it opens the meeting link, or that day in Google Calendar. All-day
  events are not announced.
- **Popup (click the clock):** days with events get a dot. Click a day to list
  its events under the month. Click an event to open its Meet, Zoom or Teams
  link, or that day in Google Calendar.

Access is **read-only**. The plugin reads each calendar's private iCal
address. It never signs in to Google and cannot change your calendar.

## Setup

```bash
./omarchy/calendar/install.sh   # install the plugin in place of Omarchy's clock
./toolbox calendar add          # add a calendar
```

`add` asks for a name and the calendar's **secret address in iCal format**:

1. Open [Google Calendar settings](https://calendar.google.com/calendar/r/settings).
2. Under **Settings for my calendars**, pick the calendar.
3. In **Integrate calendar**, copy **Secret address in iCal format**.

Paste it when asked; it is not echoed. Repeat for each calendar you want.

## Commands

```bash
./toolbox calendar add [name]         # add a calendar (address asked for, hidden)
./toolbox calendar list               # configured calendars, addresses masked
./toolbox calendar remove <name|number>
./toolbox calendar sync               # download events now
./toolbox calendar status             # last sync, event count, errors
```

The widget syncs every 5 minutes while the shell runs, and when you open the
popup.

## Privacy and limits

- **The address is a password for that calendar.** Anyone who has it can read
  every event. It is stored only in `~/.config/toolbox-calendar/calendars.conf`
  (mode 600), never in this repository. To revoke it, use **Reset** next to
  the address in Google Calendar, then `toolbox calendar remove` and `add`.
- **Google refreshes the iCal address on its own schedule.** New or moved
  events can take a while to appear, sometimes hours.
- **Work accounts** may not offer the secret address; a Google Workspace admin
  can turn it off.
- The iCal feed does not say which invitations you declined, so declined
  events still show.
- Events are kept for 45 days back and 120 days ahead, in
  `~/.local/state/toolbox-calendar/events.json`. If a calendar fails to
  download, its last events are kept and the popup shows the error.

## Settings

In `~/.config/omarchy/shell.json`, on the `toolbox.calendar` bar entry:

| Setting | Default | Meaning |
| --- | --- | --- |
| `nextEventMinutes` | `60` | How early an upcoming event appears in the bar. `0` hides it. |
| `notifyMinutes` | `30` | How early the notification is sent. `0` turns notifications off. |

The clock's own settings (`format`, `formatAlt`, week start, life bar) work as
in Omarchy's clock and carry over when the plugin replaces it.

## How it works

- `sync.py` downloads each address, expands repeating events (daily, weekly,
  monthly, yearly, including rules like "last Friday", exceptions and moved
  occurrences), and writes `events.json`. Python standard library only.
- `notify.sh` sends each notification through `omarchy notification send`
  once per occurrence (stamped in `~/.local/state/toolbox-calendar/notified/`),
  so several monitors or a shell restart do not repeat it. An event that
  moves is announced again for its new time.
- `BarWidget.qml`, `Panel.qml` and `Model.js` are Omarchy's clock (4.0.4) with
  the events added; `Events.js` holds the event math.

After an Omarchy update, compare with the stock clock and bring over changes:

```bash
diff -u /usr/share/omarchy/shell/plugins/panels/clock/Panel.qml omarchy/calendar/Panel.qml
```

To return to Omarchy's clock: `omarchy plugin disable toolbox.calendar`.

```bash
./omarchy/calendar/test.sh   # sync, recurrence and event-math tests; no network
```
