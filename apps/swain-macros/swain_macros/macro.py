"""Macro language: one step per line, parsed into steps and replayed on virtual devices."""
import subprocess
import time
import unicodedata

from evdev import ecodes as e

HELP = """\
key ctrl+c          press a key or combo (ctrl, shift, alt, super, f5, enter…)
hold shift          keep a key down  ·  release shift
type Olá, mundo!    type text
wait 200            pause, in milliseconds
click left 2        left, right, middle, side, extra (+ times)
scroll down 3       up or down (+ steps)
run nautilus        launch a command
# comment"""

STEP_DELAY = 0.008

ALIASES = {
    "ctrl": "LEFTCTRL", "control": "LEFTCTRL", "shift": "LEFTSHIFT", "alt": "LEFTALT", "altgr": "RIGHTALT",
    "super": "LEFTMETA", "win": "LEFTMETA", "meta": "LEFTMETA", "esc": "ESC", "return": "ENTER",
    "del": "DELETE", "ins": "INSERT", "pgup": "PAGEUP", "pgdn": "PAGEDOWN", "caps": "CAPSLOCK",
    "print": "SYSRQ", "prtsc": "SYSRQ", "volup": "VOLUMEUP", "voldown": "VOLUMEDOWN",
    "play": "PLAYPAUSE", "next": "NEXTSONG", "prev": "PREVIOUSSONG",
}

BUTTONS = {"left": e.BTN_LEFT, "right": e.BTN_RIGHT, "middle": e.BTN_MIDDLE, "side": e.BTN_SIDE, "extra": e.BTN_EXTRA}


class MacroError(ValueError):
    pass


def key_code(name):
    upper = ALIASES.get(name.strip().lower(), name.strip().upper())
    for candidate in (upper, "KEY_" + upper):
        if candidate.startswith("KEY_") and isinstance(e.ecodes.get(candidate), int):
            return e.ecodes[candidate]
    raise MacroError(f"unknown key '{name.strip()}'")


# --- Keyboard layouts for the `type` command: char -> [(shift, keycode), ...] ---

def _k(name):
    return e.ecodes["KEY_" + name]


def _layout(plain, shifted, dead_keys=()):
    table = {" ": [(False, e.KEY_SPACE)], "\n": [(False, e.KEY_ENTER)], "\t": [(False, e.KEY_TAB)]}
    for c in "abcdefghijklmnopqrstuvwxyz":
        table[c] = [(False, _k(c.upper()))]
        table[c.upper()] = [(True, _k(c.upper()))]
    for c in "0123456789":
        table[c] = [(False, _k(c))]
    table.update({c: [(False, _k(n))] for c, n in plain.items()})
    table.update({c: [(True, _k(n))] for c, n in shifted.items()})
    # Dead keys: the mark alone is dead key + space; accented letters are dead key + letter.
    for combining, shift, name, alone in dead_keys:
        stroke = (shift, _k(name))
        table[alone] = [stroke, (False, e.KEY_SPACE)]
        for base in "aeiouAEIOUnN":
            composed = unicodedata.normalize("NFC", base + combining)
            if len(composed) == 1 and composed not in table:
                table[composed] = [stroke] + table[base]
    return table


LAYOUTS = {
    "us": _layout(
        plain={"-": "MINUS", "=": "EQUAL", "[": "LEFTBRACE", "]": "RIGHTBRACE", ";": "SEMICOLON",
               "'": "APOSTROPHE", "`": "GRAVE", "\\": "BACKSLASH", ",": "COMMA", ".": "DOT", "/": "SLASH"},
        shifted={"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9",
                 ")": "0", "_": "MINUS", "+": "EQUAL", "{": "LEFTBRACE", "}": "RIGHTBRACE", ":": "SEMICOLON",
                 '"': "APOSTROPHE", "~": "GRAVE", "|": "BACKSLASH", "<": "COMMA", ">": "DOT", "?": "SLASH"},
    ),
    "br": _layout(  # ABNT2
        plain={"-": "MINUS", "=": "EQUAL", "[": "RIGHTBRACE", "]": "BACKSLASH", "ç": "SEMICOLON",
               "'": "GRAVE", "\\": "102ND", ",": "COMMA", ".": "DOT", ";": "SLASH", "/": "RO"},
        shifted={"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "&": "7", "*": "8", "(": "9", ")": "0",
                 "_": "MINUS", "+": "EQUAL", "{": "RIGHTBRACE", "}": "BACKSLASH", "Ç": "SEMICOLON",
                 '"': "GRAVE", "|": "102ND", "<": "COMMA", ">": "DOT", ":": "SLASH", "?": "RO"},
        dead_keys=[("́", False, "LEFTBRACE", "´"), ("̀", True, "LEFTBRACE", "`"),
                   ("̃", False, "APOSTROPHE", "~"), ("̂", True, "APOSTROPHE", "^"),
                   ("̈", True, "6", "¨")],
    ),
}


# --- Parsing ---

def parse(text, layout="br"):
    table = LAYOUTS.get(layout, LAYOUTS["br"])
    steps = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        command, _, arg = line.partition(" ")
        try:
            steps.append(_step(command.lower(), arg, table))
        except MacroError as err:
            raise MacroError(f"Line {number}: {err}") from None
    return steps


def _count(text):
    if not text:
        return 1
    if not text.isdigit() or not 0 < int(text) <= 100:
        raise MacroError(f"'{text}' is not a number between 1 and 100")
    return int(text)


def _step(command, arg, table):
    if command in ("key", "hold", "release"):
        if not arg.strip():
            raise MacroError(f"'{command}' needs a key, e.g. {command} ctrl+c")
        codes = [key_code(part) for part in arg.split("+")]
        return ("combo" if command == "key" else command, codes)

    if command == "type":
        strokes = []
        for char in arg:
            if char not in table:
                raise MacroError(f"can't type '{char}' with this keyboard layout")
            strokes += table[char]
        return ("type", strokes)

    if command == "wait":
        ms = arg.strip()
        if not ms.isdigit() or int(ms) > 60000:
            raise MacroError("wait needs milliseconds (0–60000), e.g. wait 200")
        return ("wait", int(ms) / 1000)

    if command == "click":
        name, _, count = arg.strip().lower().partition(" ")
        if name not in BUTTONS:
            raise MacroError(f"click needs one of: {', '.join(BUTTONS)}")
        return ("click", BUTTONS[name], _count(count.strip()))

    if command == "scroll":
        direction, _, count = arg.strip().lower().partition(" ")
        if direction not in ("up", "down"):
            raise MacroError("scroll needs 'up' or 'down'")
        return ("scroll", 1 if direction == "up" else -1, _count(count.strip()))

    if command == "run":
        if not arg.strip():
            raise MacroError("run needs a command, e.g. run nautilus")
        return ("run", arg.strip())

    raise MacroError(f"unknown command '{command}'")


# --- Playback ---

def run(steps, out):
    """Replay parsed steps on `out` (an engine.VirtualOutput). Keys left held are released at the end."""
    held = []

    def press(code):
        out.key(code, 1)
        time.sleep(STEP_DELAY)

    def release(code):
        out.key(code, 0)
        time.sleep(STEP_DELAY)

    try:
        for kind, *args in steps:
            if kind == "combo":
                for code in args[0]:
                    press(code)
                for code in reversed(args[0]):
                    release(code)
            elif kind == "hold":
                for code in args[0]:
                    if code not in held:
                        press(code)
                        held.append(code)
            elif kind == "release":
                for code in args[0]:
                    release(code)
                    if code in held:
                        held.remove(code)
            elif kind == "type":
                for shift, code in args[0]:
                    if shift:
                        press(e.KEY_LEFTSHIFT)
                    press(code)
                    release(code)
                    if shift:
                        release(e.KEY_LEFTSHIFT)
            elif kind == "wait":
                time.sleep(args[0])
            elif kind == "click":
                code, count = args
                for _ in range(count):
                    press(code)
                    release(code)
            elif kind == "scroll":
                amount, count = args
                for _ in range(count):
                    out.scroll(amount)
                    time.sleep(STEP_DELAY)
            elif kind == "run":
                subprocess.Popen(args[0], shell=True, start_new_session=True, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        for code in reversed(held):
            try:
                out.key(code, 0)
            except OSError:
                pass
