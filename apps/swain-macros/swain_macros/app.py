import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, GLib, Gtk  # noqa: E402

from . import config, macro  # noqa: E402
from .engine import Engine, button_name  # noqa: E402

APP_ID = "local.guibs.SwainMacros"
LAYOUTS = [("br", "Brazilian (ABNT2)"), ("us", "US")]
STATUS = {
    "starting": ("Starting…", "content-loading-symbolic"),
    "connected": ("Connected", "emblem-ok-symbolic"),
    "missing": ("Mouse not found — plug it in", "dialog-question-symbolic"),
    "permission": ("No permission to use the mouse", "dialog-warning-symbolic"),
    "busy": ("Mouse is being used by another program", "dialog-warning-symbolic"),
}


class App(Adw.Application):
    def __init__(self, start_hidden):
        super().__init__(application_id=APP_ID)
        self.start_hidden = start_hidden
        self.win = None
        self.binding_rows = []
        self.errors = {}
        self.notified_background = False
        self.cfg = config.load()
        self.engine = Engine(self.cfg["vendor"], self.cfg["product"],
                             lambda state, detail: GLib.idle_add(self._show_status))
        self.engine.enabled = self.cfg["enabled"]
        self._apply_bindings()

    def do_startup(self):
        Adw.Application.do_startup(self)
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", lambda *_: self._quit())
        self.add_action(quit_action)
        self.set_accels_for_action("app.quit", ["<Ctrl>q"])
        self.engine.start()

    def do_activate(self):
        if self.win is None:
            self._build_window()
            if self.start_hidden:
                return
        self.win.present()

    # --- Window ---

    def _build_window(self):
        self.win = Adw.ApplicationWindow(application=self, title="Swain Macros", default_width=560, default_height=680)
        self.win.connect("close-request", self._on_close)

        toolbar = Adw.ToolbarView()
        header = Adw.HeaderBar()
        menu = Gio.Menu()
        menu.append("Quit", "app.quit")
        header.pack_end(Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu))
        toolbar.add_top_bar(header)

        self.banner = Adw.Banner(title="Swain Macros needs permission to use the mouse", button_label="How to fix")
        self.banner.connect("button-clicked", self._show_permission_help)
        toolbar.add_top_bar(self.banner)

        self.toasts = Adw.ToastOverlay()
        page = Adw.PreferencesPage()
        self.toasts.set_child(page)
        toolbar.set_content(self.toasts)
        self.win.set_content(toolbar)

        mouse = Adw.PreferencesGroup(title="Mouse")
        self.status_row = Adw.ActionRow(title="Redragon Swain", use_markup=False)
        self.status_row.add_prefix(Gtk.Image(icon_name="input-mouse-symbolic"))
        self.status_icon = Gtk.Image()
        self.status_row.add_suffix(self.status_icon)
        mouse.add(self.status_row)

        enabled = Adw.SwitchRow(title="Macros enabled", active=self.cfg["enabled"])
        enabled.connect("notify::active", lambda row, _: self._set("enabled", row.get_active()))
        mouse.add(enabled)

        background = Adw.SwitchRow(title="Keep running when the window is closed", active=self.cfg["background"],
                                   subtitle="Macros keep working in the background")
        background.connect("notify::active", lambda row, _: self._set("background", row.get_active()))
        mouse.add(background)

        autostart = Adw.SwitchRow(title="Start at login", active=config.autostart_enabled())
        autostart.connect("notify::active", lambda row, _: config.set_autostart(row.get_active()))
        mouse.add(autostart)

        layout = Adw.ComboRow(title="Keyboard layout", subtitle="Used by the type command",
                              model=Gtk.StringList.new([label for _, label in LAYOUTS]))
        layout.set_selected(next((i for i, (key, _) in enumerate(LAYOUTS) if key == self.cfg["layout"]), 0))
        layout.connect("notify::selected", lambda row, _: self._set("layout", LAYOUTS[row.get_selected()][0]))
        mouse.add(layout)
        page.add(mouse)

        self.buttons_group = Adw.PreferencesGroup(
            title="Side buttons", description="Press “Add button”, then click the mouse button you want to change.")
        add = Gtk.Button(child=Adw.ButtonContent(icon_name="list-add-symbolic", label="Add button"))
        add.add_css_class("flat")
        add.connect("clicked", self._add_button)
        self.buttons_group.set_header_suffix(add)
        page.add(self.buttons_group)

        self._refresh_bindings()
        self._show_status()

    def _show_status(self):
        if self.win is None:
            return
        text, icon = STATUS[self.engine.state]
        if self.engine.state == "connected" and self.engine.detail:
            text = f"Connected — {self.engine.detail}"
        self.status_row.set_subtitle(text)
        self.status_icon.set_from_icon_name(icon)
        self.banner.set_revealed(self.engine.state == "permission")

    def _show_permission_help(self, *_):
        dialog = Adw.AlertDialog(
            heading="Allow access to the mouse",
            body=f"Open a terminal and run this once:\n\n{config.LAUNCHER.parent}/install.sh\n\n"
                 "It lets your user read the mouse and create the virtual devices used by macros. "
                 "Then quit and reopen Swain Macros.")
        dialog.add_response("ok", "OK")
        dialog.present(self.win)

    def _on_close(self, win):
        if self.cfg["background"]:
            win.set_visible(False)
            if not self.notified_background:
                self.notified_background = True
                note = Gio.Notification.new("Swain Macros is still running")
                note.set_body("Your macros keep working. Open the app again to change them, or use Quit in its menu.")
                self.send_notification("background", note)
            return True
        self.engine.stop()
        return False

    def _quit(self):
        self.engine.stop()
        self.quit()

    def _toast(self, text):
        self.toasts.add_toast(Adw.Toast(title=text))

    # --- Settings & bindings ---

    def _set(self, key, value):
        self.cfg[key] = value
        if key == "enabled":
            self.engine.enabled = value
        if key == "layout":
            self._apply_bindings()
            self._refresh_bindings()
        config.save(self.cfg)

    def _apply_bindings(self):
        bindings, self.errors = {}, {}
        for b in self.cfg["bindings"]:
            try:
                bindings[b["code"]] = macro.parse(b["macro"], self.cfg["layout"])
            except macro.MacroError as err:
                self.errors[b["code"]] = str(err)
        self.engine.bindings = bindings

    def _save_bindings(self):
        config.save(self.cfg)
        self._apply_bindings()
        self._refresh_bindings()

    def _refresh_bindings(self):
        for row in self.binding_rows:
            self.buttons_group.remove(row)
        self.binding_rows = []

        if not self.cfg["bindings"]:
            empty = Adw.ActionRow(title="No buttons configured yet", subtitle="Your mouse works as usual until you add one")
            self.buttons_group.add(empty)
            self.binding_rows.append(empty)

        for b in sorted(self.cfg["bindings"], key=lambda b: b["code"]):
            code = b["code"]
            lines = [line.strip() for line in b["macro"].splitlines() if line.strip() and not line.strip().startswith("#")]
            summary = f"⚠ {self.errors[code]}" if code in self.errors else " · ".join(lines) or "(does nothing)"
            row = Adw.ActionRow(title=b.get("label") or button_name(code), subtitle=summary,
                                subtitle_lines=1, activatable=True, use_markup=False)
            row.connect("activated", lambda _row, code=code: self._edit(code))
            delete = Gtk.Button(icon_name="user-trash-symbolic", valign=Gtk.Align.CENTER, tooltip_text="Remove")
            delete.add_css_class("flat")
            delete.connect("clicked", lambda _btn, code=code: self._delete(code))
            row.add_suffix(delete)
            row.add_suffix(Gtk.Image(icon_name="go-next-symbolic"))
            self.buttons_group.add(row)
            self.binding_rows.append(row)

    def _delete(self, code):
        self.cfg["bindings"] = [b for b in self.cfg["bindings"] if b["code"] != code]
        self._save_bindings()
        self._toast(f"{button_name(code)} restored to normal")

    def _add_button(self, *_):
        if self.engine.state != "connected":
            self._toast("Connect the mouse first")
            return
        dialog = Adw.AlertDialog(heading="Press a mouse button",
                                 body="Click the side button you want to change.\nThe left button can’t be used.")
        dialog.add_response("cancel", "Cancel")
        dialog.connect("response", lambda *_: self.engine.cancel_capture())

        def captured(code):
            dialog.force_close()
            self._edit(code)

        self.engine.capture(lambda code: GLib.idle_add(captured, code))
        dialog.present(self.win)

    def _edit(self, code):
        existing = next((b for b in self.cfg["bindings"] if b["code"] == code), None)
        dialog = Adw.Dialog(title=button_name(code), content_width=580, content_height=640)
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar())
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                      margin_top=6, margin_bottom=18, margin_start=18, margin_end=18)
        view.set_content(box)
        dialog.set_child(view)

        names = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
        names.add_css_class("boxed-list")
        name_row = Adw.EntryRow(title="Name", text=existing.get("label", "") if existing else button_name(code))
        names.append(name_row)
        box.append(names)

        buffer = Gtk.TextBuffer(text=existing["macro"] if existing else "key ctrl+c\n")
        text = Gtk.TextView(buffer=buffer, monospace=True, wrap_mode=Gtk.WrapMode.WORD_CHAR,
                            top_margin=10, bottom_margin=10, left_margin=10, right_margin=10)
        scroller = Gtk.ScrolledWindow(child=text, min_content_height=160, vexpand=True)
        scroller.add_css_class("card")
        box.append(scroller)

        error = Gtk.Label(xalign=0, wrap=True, visible=False)
        error.add_css_class("error")
        box.append(error)

        help_label = Gtk.Label(label=macro.HELP, xalign=0, selectable=True)
        help_label.add_css_class("dim-label")
        help_label.add_css_class("monospace")
        box.append(help_label)

        actions = Gtk.Box(spacing=12, halign=Gtk.Align.END)
        test = Gtk.Button(label="Test in 3 s", tooltip_text="Runs the macro after 3 seconds, so you can focus another window")
        save = Gtk.Button(label="Save")
        save.add_css_class("suggested-action")
        actions.append(test)
        actions.append(save)
        box.append(actions)

        def parsed():
            try:
                steps = macro.parse(buffer.props.text, self.cfg["layout"])
            except macro.MacroError as err:
                error.set_label(str(err))
                error.set_visible(True)
                return None
            error.set_visible(False)
            return steps

        def on_test(_btn):
            steps = parsed()
            if steps is None:
                return
            test.set_sensitive(False)
            test.set_label("Running in 3 s…")

            def fire():
                test.set_sensitive(True)
                test.set_label("Test in 3 s")
                if not self.engine.run_now(steps):
                    error.set_label("Can't run macros: the mouse isn't connected or permission is missing.")
                    error.set_visible(True)
                return False

            GLib.timeout_add_seconds(3, fire)

        def on_save(_btn):
            if parsed() is None:
                return
            others = [b for b in self.cfg["bindings"] if b["code"] != code]
            self.cfg["bindings"] = others + [{"code": code, "label": name_row.get_text().strip(), "macro": buffer.props.text}]
            self._save_bindings()
            dialog.close()
            self._toast("Macro saved")

        test.connect("clicked", on_test)
        save.connect("clicked", on_save)
        dialog.present(self.win)


def main(argv):
    app = App(start_hidden="--background" in argv)
    return app.run([arg for arg in argv if arg != "--background"])
