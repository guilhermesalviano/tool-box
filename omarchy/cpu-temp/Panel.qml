import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// CPU temperature, always in the bar.
//
// The bar shows a thermometer and the CPU package temperature, and turns the
// urgent colour at `alertAt` °C. Clicking opens every CPU sensor (package and
// each core) with its critical limit; right click opens btop.
//
// sensors.sh finds the sensor files once (and again when one stops reading,
// e.g. after hwmon renumbering); the bar then reads the package sensor file
// directly every `refreshSeconds`, without starting a process. While the
// panel is open, sensors.sh runs every 2 seconds to refresh all cores.
Panel {
  id: root
  moduleName: "toolbox.cpu-temp"
  ipcTarget: "toolbox.cpu-temp"
  manageIpc: false

  property var snapshot: null
  property var celsius: null
  readonly property var model: Model.normalize(snapshot)
  readonly property bool available: model.available && celsius !== null
  readonly property real ceilingCelsius: Model.ceiling(model.primary)
  readonly property int refreshSeconds: Math.max(1, Number(setting("refreshSeconds", 2)) || 2)
  readonly property real alertAt: {
    var value = Number(setting("alertAt", 85))
    return isFinite(value) ? value : 85
  }
  readonly property bool hot: Model.isHot(celsius, alertAt)

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color urgent: bar ? bar.urgent : Color.urgent

  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function discover() {
    if (!sensorsProc.running) sensorsProc.running = true
  }

  function readPrimary() {
    if (!model.available) return
    tempFile.reload()
    var value = Model.parseMillis(tempFile.text())
    if (value === null) {
      celsius = null
      discover()
    } else {
      celsius = value
    }
  }

  function openMonitor() {
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
    close()
  }

  onOpenedChanged: if (opened) discover()
  onAvailableChanged: if (!available && opened) close()

  visible: available
  implicitWidth: available ? button.implicitWidth : 0
  implicitHeight: available ? button.implicitHeight : 0

  IpcHandler {
    target: "toolbox.cpu-temp"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.discover() }
  }

  Process {
    id: sensorsProc
    command: ["bash", root.pluginFile("sensors.sh")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.snapshot = JSON.parse(text) } catch (e) { root.snapshot = null }
        root.celsius = root.model.available ? root.model.primary.celsius : null
      }
    }
  }

  FileView {
    id: tempFile
    path: root.model.available ? root.model.primary.path : ""
    blockAllReads: true
    printErrors: false
  }

  Component.onCompleted: discover()

  Timer {
    interval: root.refreshSeconds * 1000
    running: !root.opened
    repeat: true
    onTriggered: root.readPrimary()
  }

  Timer {
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.discover()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barText(root.celsius, root.ceilingCelsius, button.vertical)
    active: root.hot
    tooltipText: root.opened ? "" : Model.summary(root.model, root.celsius)
    horizontalMargin: 8.75
    onPressed: function(b) {
      if (b === Qt.RightButton) root.openMonitor()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.available
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(Math.min(column.implicitHeight, Style.space(560)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          // ---------- Hero ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: root.celsius === null ? "" : Model.glyph(root.celsius, root.ceilingCelsius)
              color: root.hot ? root.urgent : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: root.celsius === null ? "CPU" : "CPU " + Model.degrees(root.celsius)
                color: root.hot ? root.urgent : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                text: {
                  var parts = [root.model.source]
                  if (root.model.primary && root.model.primary.crit) parts.push("crit " + Model.degrees(root.model.primary.crit))
                  return parts.filter(function(p) { return p !== "" }).join(" · ").toUpperCase()
                }
                color: Qt.darker(root.fg, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          PanelSeparator {
            visible: root.model.others.length > 0
            foreground: root.fg
          }

          // ---------- Other sensors (cores) ----------
          Repeater {
            model: root.model.others

            Item {
              id: sensorRow
              required property var modelData
              readonly property bool rowHot: Model.isHot(modelData.celsius, root.alertAt)
              width: column.width
              implicitHeight: Math.max(sensorLabel.implicitHeight, sensorValue.implicitHeight)

              Text {
                id: sensorLabel
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.right: sensorValue.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: sensorRow.modelData.label
                color: root.fg
                opacity: 0.75
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                id: sensorValue
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: Model.degrees(sensorRow.modelData.celsius)
                color: sensorRow.rowHot ? root.urgent : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: sensorRow.rowHot
              }
            }
          }
        }
      }
    }
  }
}
