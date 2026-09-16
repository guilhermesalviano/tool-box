import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui

// Search-box overlay. Summon with an optional query:
//   omarchy-shell shell summon toolbox.web-search '{"query":"linux audio"}'
// A non-empty query opens the browser straight away; otherwise the box asks for one.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string error: ""

  property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  property int cardWidth: Math.min(Style.space(700), panel.width - Style.gapsOut * 2)

  // Absolute path of a file shipped next to this QML file in the plugin folder.
  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) { payload = {} }
    root.error = ""
    queryInput.text = String(payload.query || "")
    if (queryInput.text.trim()) {
      root.search()
      return
    }
    root.opened = true
    Qt.callLater(function() { queryInput.forceActiveFocus() })
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "toolbox.web-search")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function search() {
    var query = queryInput.text.trim()
    if (!query || launcher.running) return
    root.error = ""
    launcher.command = ["bash", root.pluginFile("run.sh"), query]
    launcher.running = true
  }

  Process {
    id: launcher
    stderr: StdioCollector {
      id: launcherErrors
      waitForEnd: true
    }
    onExited: function(code) {
      if (code === 0) {
        root.dismiss()
        return
      }
      root.error = launcherErrors.text.trim() || "Could not open the browser."
      root.opened = true
      Qt.callLater(function() { queryInput.forceActiveFocus() })
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "toolbox-web-search"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: content.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: Style.cornerRadius
      anchors.centerIn: parent
      color: Color.menu.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.spacing.md

        Text {
          text: "󰖟  Search Web"
          color: Color.menu.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
        }

        Controls.TextField {
          id: queryInput
          width: parent.width
          placeholderText: "Search the internet…"
          color: Color.menu.text
          placeholderTextColor: Qt.alpha(Color.menu.text, 0.5)
          selectionColor: Color.menu.selectedBackground
          selectedTextColor: Color.menu.selectedText
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          padding: Style.space(12)
          selectByMouse: true
          readOnly: launcher.running
          onAccepted: root.search()
          Keys.onEscapePressed: function(event) {
            root.dismiss()
            event.accepted = true
          }
          background: Rectangle {
            color: "transparent"
            radius: Style.cornerRadius
            border.width: 1
            border.color: Color.menu.border
          }
        }

        Text {
          width: parent.width
          text: root.error || "Enter to open in your default browser · Esc to close"
          color: Color.menu.text
          opacity: root.error ? 1 : 0.6
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
