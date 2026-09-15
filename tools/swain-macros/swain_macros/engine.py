"""Grabs the mouse, passes its events through virtual devices, and runs macros for bound buttons."""
import errno
import queue
import select
import sys
import threading
from pathlib import Path

from evdev import InputDevice, UInput, UInputError, ecodes as e

from . import macro

BUTTON_NAMES = {
    e.BTN_SIDE: "Side button (back)",
    e.BTN_EXTRA: "Side button (forward)",
    e.BTN_BACK: "Back button",
    e.BTN_FORWARD: "Forward button",
    e.BTN_TASK: "Task button",
    e.BTN_MIDDLE: "Wheel click",
    e.BTN_RIGHT: "Right click",
}


def button_name(code):
    if code in BUTTON_NAMES:
        return BUTTON_NAMES[code]
    name = e.BTN.get(code) or e.KEY.get(code) or f"Code {code}"
    return name[0] if isinstance(name, list) else name


def find_device_paths(vendor, product):
    """Event nodes of the mouse, found via sysfs so it works even before we have permission to open them."""
    paths = []
    for node in sorted(Path("/sys/class/input").glob("event*")):
        try:
            ids = (node / "device/id/vendor").read_text().strip(), (node / "device/id/product").read_text().strip()
        except OSError:
            continue
        if ids == (vendor, product):
            paths.append(f"/dev/input/{node.name}")
    return paths


class VirtualOutput:
    """A virtual pointer and keyboard that receive pass-through events and macro output."""

    def __init__(self, rel_codes):
        self.rels = sorted(set(rel_codes) | {e.REL_X, e.REL_Y, e.REL_WHEEL})
        self.pointer = UInput({e.EV_KEY: list(range(e.BTN_LEFT, e.BTN_TASK + 1)), e.EV_REL: self.rels},
                              name="Swain Macros pointer")
        keys = [c for c in e.KEY if 0 < c < e.BTN_MISC or e.KEY_OK <= c < e.KEY_MAX]
        self.keyboard = UInput({e.EV_KEY: keys}, name="Swain Macros keyboard")
        self._lock = threading.Lock()

    def write_frame(self, events):
        with self._lock:
            used = []
            for etype, code, value in events:
                is_pointer = etype == e.EV_REL or e.BTN_MISC <= code < e.KEY_OK
                dev = self.pointer if is_pointer else self.keyboard
                dev.write(etype, code, value)
                if dev not in used:
                    used.append(dev)
            for dev in used:
                dev.syn()

    def key(self, code, value):
        self.write_frame([(e.EV_KEY, code, value)])

    def scroll(self, amount):
        frame = [(e.EV_REL, e.REL_WHEEL, amount)]
        if e.REL_WHEEL_HI_RES in self.rels:
            frame.append((e.EV_REL, e.REL_WHEEL_HI_RES, amount * 120))
        self.write_frame(frame)

    def close(self):
        self.pointer.close()
        self.keyboard.close()


class Engine:
    def __init__(self, vendor, product, on_status):
        self.vendor, self.product = vendor, product
        self.on_status = on_status  # called from a worker thread with (state, detail)
        self.bindings = {}  # button code -> parsed macro steps
        self.enabled = True
        self.state, self.detail = "starting", ""
        self.out = None
        self._capture = None
        self._swallow = set()
        self._jobs = queue.Queue()
        self._stop = threading.Event()

    def start(self):
        for target in (self._device_loop, self._macro_loop):
            threading.Thread(target=target, daemon=True).start()

    def stop(self):
        self._stop.set()
        self._jobs.put(None)

    def capture(self, callback):
        """Call `callback(code)` (from the engine thread) with the next button pressed, instead of acting on it."""
        self._capture = callback

    def cancel_capture(self):
        self._capture = None

    def run_now(self, steps):
        if self.out is None:
            return False
        self._jobs.put(steps)
        return True

    def _set_state(self, state, detail=""):
        if (state, detail) != (self.state, self.detail):
            self.state, self.detail = state, detail
            self.on_status(state, detail)

    def _device_loop(self):
        while not self._stop.is_set():
            paths = find_device_paths(self.vendor, self.product)
            if not paths:
                self._set_state("missing")
                self._stop.wait(2)
                continue
            devices = []
            try:
                devices = [InputDevice(p) for p in paths]
                rels = {c for d in devices for c in d.capabilities().get(e.EV_REL, [])}
                self.out = VirtualOutput(rels)  # before grabbing, so a failure never leaves the mouse dead
                for d in devices:
                    d.grab()
                self._set_state("connected", devices[0].name)
                self._pump(devices)
            except (PermissionError, UInputError):
                self._set_state("permission")
                self._stop.wait(3)
            except OSError as err:
                self._set_state("busy" if err.errno == errno.EBUSY else "missing")
                self._stop.wait(2)
            finally:
                for d in devices:
                    try:
                        d.ungrab()
                    except OSError:
                        pass
                    d.close()
                if self.out:
                    self.out.close()
                    self.out = None

    def _pump(self, devices):
        by_fd = {d.fd: d for d in devices}
        pending = {fd: [] for fd in by_fd}
        while not self._stop.is_set():
            ready, _, _ = select.select(list(by_fd), [], [], 0.5)
            for fd in ready:
                for ev in by_fd[fd].read():
                    self._handle(ev, pending[fd])

    def _handle(self, ev, pending):
        if ev.type == e.EV_SYN:
            if ev.code == e.SYN_REPORT and pending:
                self.out.write_frame(pending)
            pending.clear()
        elif ev.type == e.EV_KEY:
            if self._capture and ev.value == 1 and ev.code != e.BTN_LEFT:
                callback, self._capture = self._capture, None
                self._swallow.add(ev.code)
                callback(ev.code)
            elif ev.code in self._swallow:  # repeat/release of a button we already acted on
                if ev.value == 0:
                    self._swallow.discard(ev.code)
            elif self.enabled and ev.code in self.bindings:
                if ev.value == 1:
                    self._jobs.put(self.bindings[ev.code])
                    self._swallow.add(ev.code)
            else:
                pending.append((ev.type, ev.code, ev.value))
        elif ev.type == e.EV_REL:
            pending.append((ev.type, ev.code, ev.value))
        # Scan codes (EV_MSC) and anything else are dropped.

    def _macro_loop(self):
        while (steps := self._jobs.get()) is not None:
            out = self.out
            if out is None:
                continue
            try:
                macro.run(steps, out)
            except Exception as err:  # a closed device mid-macro shouldn't kill the worker
                print(f"swain-macros: macro failed: {err}", file=sys.stderr)
