import QtQuick
import QtQuick.Controls as Controls
import Quickshell.Io
import Quickshell
import qs.Commons

FocusScope {
  id: pane
  signal backRequested()
  property string answer: ""
  property string error: ""
  property string output: ""
  property string diagnostics: ""
  property bool cancelled: false
  property int elapsed: 0
  property string pendingQuestion: ""
  readonly property bool busy: request.running

  // Absolute path of a file shipped next to this QML file in the plugin folder.
  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function open(question) {
    answer = ""
    error = ""
    questionInput.text = question || ""
    Qt.callLater(function() { questionInput.forceActiveFocus() })
    if (questionInput.text.trim()) {
      if (busy) pendingQuestion = questionInput.text
      else submit()
    }
  }

  function stop() {
    pendingQuestion = ""
    if (busy) {
      cancelled = true
      request.signal(15)
    }
  }

  function submit() {
    var question = questionInput.text.trim()
    if (!question || busy) return
    answer = ""
    error = ""
    output = ""
    diagnostics = ""
    elapsed = 0
    cancelled = false
    responseScroll.contentItem.contentY = 0
    request.command = ["bash", pane.pluginFile("answer.sh"), question]
    request.running = true
  }

  Keys.onEscapePressed: function(event) {
    stop()
    backRequested()
    event.accepted = true
  }

  Timer {
    interval: 1000
    repeat: true
    running: pane.busy
    onTriggered: pane.elapsed += 1
  }

  Process {
    id: request
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: pane.output = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: pane.diagnostics = text
    }
    onExited: function(code) {
      if (pane.cancelled) pane.error = "Request cancelled."
      else if (code !== 0) pane.error = pane.diagnostics.trim() || "Could not start the AI request. Please retry."
      else if (!pane.output.trim()) pane.error = "No answer received. Please retry."
      else pane.answer = pane.output.trim()
      if (pane.pendingQuestion) {
        questionInput.text = pane.pendingQuestion
        pane.pendingQuestion = ""
        Qt.callLater(function() { pane.submit() })
      }
    }
  }

  component ActionButton: Controls.Button {
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    padding: Style.space(10)
    background: Rectangle {
      radius: Style.cornerRadius
      color: parent.hovered ? Color.menu.selectedBackground : "transparent"
      border.width: 1
      border.color: Color.menu.border
      opacity: parent.enabled ? 1 : 0.4
    }
    contentItem: Text {
      text: parent.text
      font: parent.font
      color: Color.menu.text
      opacity: parent.enabled ? 1 : 0.4
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }

  Row {
    id: heading
    width: parent.width
    spacing: Style.spacing.md
    ActionButton {
      text: "‹ Search"
      onClicked: { pane.stop(); pane.backRequested() }
    }
    Text {
      text: "Ask AI"
      color: Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Controls.TextField {
    id: questionInput
    anchors.top: heading.bottom
    anchors.topMargin: Style.spacing.md
    width: parent.width
    placeholderText: "Ask a question…"
    color: Color.menu.text
    placeholderTextColor: Qt.alpha(Color.menu.text, 0.5)
    selectionColor: Color.menu.selectedBackground
    selectedTextColor: Color.menu.selectedText
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
    padding: Style.space(12)
    selectByMouse: true
    readOnly: pane.busy
    onAccepted: pane.submit()
    background: Rectangle {
      color: "transparent"
      radius: Style.cornerRadius
      border.width: 1
      border.color: Color.menu.border
    }
  }

  Text {
    id: status
    anchors.top: questionInput.bottom
    anchors.topMargin: Style.spacing.md
    width: parent.width
    text: pane.busy ? "Thinking… " + pane.elapsed + "s" : pane.error ? "Unable to answer" : pane.answer ? "Answer" : "Enter to ask · Esc to return to search"
    color: Color.menu.text
    opacity: 0.6
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
  }

  Controls.ScrollView {
    id: responseScroll
    anchors.top: status.bottom
    anchors.topMargin: Style.spacing.md
    anchors.bottom: actions.top
    anchors.bottomMargin: Style.spacing.md
    width: parent.width
    clip: true
    contentWidth: availableWidth
    Controls.TextArea {
      id: response
      text: pane.error || pane.answer || (pane.busy ? "Your answer will appear here." : "Ask a question and read the response here. Each question starts a new conversation.")
      readOnly: true
      selectByMouse: true
      textFormat: TextEdit.PlainText
      wrapMode: TextEdit.Wrap
      color: Color.menu.text
      selectionColor: Color.menu.selectedBackground
      selectedTextColor: Color.menu.selectedText
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      background: null
      padding: 0
    }
  }

  Row {
    id: actions
    anchors.bottom: parent.bottom
    spacing: Style.spacing.md
    ActionButton {
      text: pane.busy ? "Cancel" : pane.error ? "Retry" : "Ask"
      enabled: pane.busy || questionInput.text.trim().length > 0
      onClicked: { if (pane.busy) pane.stop(); else pane.submit() }
    }
    ActionButton {
      text: "Copy answer"
      enabled: pane.answer.length > 0
      onClicked: { response.selectAll(); response.copy(); response.deselect() }
    }
  }
}
