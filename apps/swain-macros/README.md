# Swain Macros

A small GNOME app for Ubuntu that replaces what the side buttons of the Redragon Swain mouse
(Holtek `04d9:fc63`) do with macros. Works on Wayland and X11.

## Install

```bash
./install.sh                     # or: ./toolbox swain-macros install
```

Run it as your normal user (it asks for `sudo` when needed). It installs the Python/GTK packages,
adds a udev rule so your user can use the mouse and `/dev/uinput`, and adds "Swain Macros" to the app menu.

It uses the system `python3`, not the shared `.venv`: PyGObject (GTK) and evdev come from apt.

Note: the udev rule lets any program running as your logged-in user create virtual input devices
(and so type keystrokes). That's what the app needs to replay macros.

Launch it from the app menu, or with `./toolbox swain-macros` (`--background` starts it hidden).

## Use

1. Open **Swain Macros**, click **Add button**, then press a side button.
2. Write the macro and click **Save**. **Test in 3 s** runs it so you can try it in another window.

```
key ctrl+c          press a key or combo (ctrl, shift, alt, super, f5, enter…)
hold shift          keep a key down  ·  release shift
type Olá, mundo!    type text (Brazilian ABNT2 or US layout)
wait 200            pause, in milliseconds
click left 2        left, right, middle, side, extra (+ times)
scroll down 3       up or down (+ steps)
run nautilus        launch a command
# comment
```

Closing the window keeps macros running (turn that off in the app); **Quit** is in the menu.
Settings live in `~/.config/swain-macros/config.json`.

## How it works

The app grabs the mouse's input devices and re-sends every event through a virtual pointer and keyboard
(`uinput`). Presses of a button with a macro are swallowed and the macro is played instead. If the app
stops, the grab is released and the mouse goes back to normal.

## Uninstall

```bash
sudo rm /etc/udev/rules.d/70-swain-macros.rules /etc/modules-load.d/swain-macros.conf
rm ~/.local/share/applications/local.guibs.SwainMacros.desktop \
   ~/.local/share/icons/hicolor/256x256/apps/local.guibs.SwainMacros.png \
   ~/.config/autostart/swain-macros.desktop
```
