import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Orca workspaces and the agents running in them.
//
// The bar shows how many workspaces Orca has open and how many agents are
// running; it turns the urgent colour when an agent is waiting for approval
// or for an answer. Clicking opens a list of workspaces with their agents;
// clicking a row brings Orca to the front on that workspace's terminal.
//
// Data comes from Orca's own CLI (snapshot.sh), polled every
// `refreshSeconds` and every few seconds while the panel is open. The widget
// leaves the bar while Orca is closed.
//
// Workspace names, branches and prompts are user text, so every Text carries
// `textFormat: Text.PlainText`: on the default AutoText Qt may render it as
// rich text, and rich text loads remote images.
Panel {
  id: root
  moduleName: "toolbox.orca"
  ipcTarget: "toolbox.orca"
  manageIpc: false

  property var snapshot: null
  property double now: Date.now()
  readonly property var model: Model.normalize(snapshot, now)
  readonly property bool running: model.running
  readonly property int refreshSeconds: Math.max(3, Number(setting("refreshSeconds", 10)) || 10)

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color urgent: bar ? bar.urgent : Color.urgent

  readonly property string barText: {
    if (!running) return ""
    if (button.vertical) return "󰚩"
    return "󰉋 " + model.workspaceCount + "  󰚩 " + model.activeAgents
  }

  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function refresh() {
    now = Date.now()
    if (!snapshotProc.running) snapshotProc.running = true
  }

  function focusOrca(handle) {
    Quickshell.execDetached(["bash", pluginFile("focus.sh"), handle || ""])
    close()
  }

  onOpenedChanged: if (opened) refresh()
  onRunningChanged: if (!running && opened) close()

  visible: running
  implicitWidth: running ? button.implicitWidth : 0
  implicitHeight: running ? button.implicitHeight : 0

  IpcHandler {
    target: "toolbox.orca"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Process {
    id: snapshotProc
    command: ["bash", root.pluginFile("snapshot.sh")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.snapshot = JSON.parse(text) } catch (e) { root.snapshot = { running: false, error: "Unreadable Orca output" } }
        root.now = Date.now()
      }
    }
  }

  Timer {
    interval: (root.opened ? 3 : root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    active: root.model.attention > 0
    tooltipText: root.opened ? "" : Model.summary(root.model)
    horizontalMargin: 8.75
    onPressed: function(b) {
      if (b === Qt.RightButton) root.focusOrca("")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.running
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
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
              text: "󰚩"
              color: root.model.attention > 0 ? root.urgent : root.fg
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
                text: "Orca"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                text: Model.summary(root.model).toUpperCase()
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

          PanelSeparator { foreground: root.fg }

          Text {
            visible: root.model.workspaceCount === 0
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "No workspaces yet. Add a project in Orca to see its workspaces and agents here."
            color: root.fg
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // ---------- Workspaces ----------
          Repeater {
            model: root.model.workspaces

            Rectangle {
              id: workspaceRow
              required property var modelData
              width: column.width
              implicitHeight: workspaceColumn.implicitHeight + Style.space(12)
              radius: Style.space(6)
              color: workspaceMouse.containsMouse
                ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                : "transparent"

              MouseArea {
                id: workspaceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusOrca(workspaceRow.modelData.handle)
              }

              Column {
                id: workspaceColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    id: workspaceDot
                    textFormat: Text.PlainText
                    text: workspaceRow.modelData.attention ? "󰀦" : (workspaceRow.modelData.working ? "󰐾" : "󰝦")
                    color: workspaceRow.modelData.attention ? root.urgent : root.fg
                    opacity: workspaceRow.modelData.working ? 1 : 0.45
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: workspaceRow.modelData.name
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: workspaceRow.modelData.working || workspaceRow.modelData.unread
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - workspaceDot.implicitWidth - repoText.implicitWidth - parent.spacing * 2)
                  }

                  Text {
                    id: repoText
                    textFormat: Text.PlainText
                    text: workspaceRow.modelData.repo
                    color: root.fg
                    opacity: 0.5
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Repeater {
                  model: workspaceRow.modelData.agents

                  Rectangle {
                    id: agentRow
                    required property var modelData
                    width: workspaceColumn.width
                    implicitHeight: agentColumn.implicitHeight + Style.space(6)
                    radius: Style.space(4)
                    color: agentMouse.containsMouse
                      ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                      : "transparent"

                    MouseArea {
                      id: agentMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.focusOrca(agentRow.modelData.handle || workspaceRow.modelData.handle)
                    }

                    Column {
                      id: agentColumn
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: Style.space(22)
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: {
                          var a = agentRow.modelData
                          var parts = [a.name, a.stateLabel]
                          if (a.tool && a.state === "working") parts.push(a.tool)
                          if (a.since) parts.push(a.since)
                          return parts.join(" · ")
                        }
                        color: agentRow.modelData.attention ? root.urgent : root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: agentRow.modelData.attention
                      }

                      Text {
                        visible: text !== ""
                        width: parent.width
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: agentRow.modelData.task
                        color: root.fg
                        opacity: 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
