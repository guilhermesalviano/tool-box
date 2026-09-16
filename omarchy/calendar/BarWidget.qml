import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Events.js" as Events

// Date/time label for the bar, and the host for the calendar popup.
//
// toolbox.calendar: this copy of Omarchy's clock also runs sync.py every few
// minutes, reads the events it writes, and appends the next timed event to
// the label while it is under way or starts within `nextEventMinutes`. It
// also sends a desktop notification `notifyMinutes` before each timed event.
//
// Left click reveals the calendar — asking "what is the date?" is what a
// click on a clock means — right click walks the common label formats, and
// middle click opens the timezone picker.
BarWidget {
  id: root
  moduleName: "omarchy.clock"

  property date displayDate: clock.date

  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")

  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))

  // What the bar shows is what shell.json stores, so a cycled format is the
  // format from then on rather than something that reverts on restart.
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: formatted(displayDate)
  readonly property string barText: nextEvent
    ? displayText + "  ·  " + Events.barLabel(nextEvent, displayDate.getTime())
    : displayText

  // ---- Events. sync.py writes the file; the FileView notices the rewrite.
  readonly property string eventsPath: Quickshell.env("HOME") + "/.local/state/toolbox-calendar/events.json"
  property var rawEvents: null
  readonly property var events: Events.normalize(rawEvents)
  readonly property var nextEvent: vertical ? null : Events.barEvent(events, displayDate.getTime(), setting("nextEventMinutes", 60))
  readonly property bool syncing: syncProcess.running

  // Absolute path of a file shipped next to this QML file in the plugin folder.
  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function sync() {
    if (!syncProcess.running) syncProcess.running = true
  }

  // ---- Notifications. notify.sh stamps each occurrence on disk, so a second
  //      monitor's bar or a shell restart does not announce it again; the
  //      in-memory set only saves spawning it every minute.
  property var announced: ({})

  function checkNotifications() {
    var nowMs = displayDate.getTime()
    var due = Events.dueNotifications(events, nowMs, setting("notifyMinutes", 30))
    for (var i = 0; i < due.length; i++) {
      var event = due[i]
      var key = Events.notificationKey(event)
      if (announced[key]) continue
      announced[key] = true
      var time = Qt.formatTime(new Date(event.startMs), "HH:mm") + "–" + Qt.formatTime(new Date(event.endMs), "HH:mm")
      Quickshell.execDetached(["bash", pluginFile("notify.sh"), key, event.title,
        Events.notificationBody(event, nowMs, time), Events.eventUrl(event)])
    }
  }

  onDisplayDateChanged: checkNotifications()
  onEventsChanged: checkNotifications()
  readonly property var verticalLines: displayText.split("\n")

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var next = Model.nextClockFormat(formatRing, current)
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function formatted(date) {
    return Qt.formatDateTime(date, activeFormat.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())))
  }

  // ---- Calendar popup. Shape contract for shell.summon/hide/toggle
  //      routing: Bar.findPanelWidget requires open/close/opened on the
  //      bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  // The clock fills more slot than it paints a mark for, at both
  // orientations: horizontally it is a text label in a padded slot, so the
  // dot takes the label width; vertically it is a stack of icon-sized lines,
  // so the dot takes one line — the same mark every icon widget gets, rather
  // than a rule running the height of the whole stack.
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  FileView {
    path: root.eventsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.rawEvents = JSON.parse(text()) } catch (e) { root.rawEvents = null }
    }
    onLoadFailed: root.rawEvents = null
    onFileChanged: reload()
  }

  Process {
    id: syncProcess
    command: ["python3", root.pluginFile("sync.py")]
  }

  Timer {
    interval: 5 * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.sync()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "omarchy.clock"

    function refresh(): void { root.broadcast("refresh") }
    function sync(): void { root.sync() }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.barText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
