import json
import os
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
CONFIG_FILE = CONFIG_HOME / "swain-macros" / "config.json"
AUTOSTART_FILE = CONFIG_HOME / "autostart" / "swain-macros.desktop"
LAUNCHER = Path(__file__).resolve().parent.parent / "swain-macros"

# Redragon Swain reports itself as Holtek "USB Gaming Mouse" 04d9:fc63.
DEFAULTS = {"vendor": "04d9", "product": "fc63", "enabled": True, "background": True, "layout": "br"}


def load():
    try:
        data = json.loads(CONFIG_FILE.read_text())
    except (OSError, ValueError):
        data = {}
    return {**DEFAULTS, "bindings": [], **data}


def save(cfg):
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))
    tmp.replace(CONFIG_FILE)


def autostart_enabled():
    return AUTOSTART_FILE.exists()


def set_autostart(enabled):
    if not enabled:
        AUTOSTART_FILE.unlink(missing_ok=True)
        return
    AUTOSTART_FILE.parent.mkdir(parents=True, exist_ok=True)
    AUTOSTART_FILE.write_text(
        "[Desktop Entry]\nType=Application\nName=Swain Macros\n"
        f'Exec="{LAUNCHER}" --background\nIcon=local.guibs.SwainMacros\nNoDisplay=true\n'
        "X-GNOME-Autostart-enabled=true\n"
    )
