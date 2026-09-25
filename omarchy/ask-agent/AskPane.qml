import QtQuick
import QtQuick.Controls as Controls
import Quickshell.Io
import Quickshell
import qs.Commons

FocusScope {
  id: pane
  signal backRequested()
  signal closeRequested()
  property string answer: ""
  property string error: ""
  property string output: ""
  property string diagnostics: ""
  property bool cancelled: false
  property int elapsed: 0
  property string pendingQuestion: ""
  // The answering agent (OpenCode by default, see answer.sh), re-read on every
  // open so changing it takes effect on the next question. answer.sh exits 3 when that agent has no
  // inline mode; the question can then be opened in the agent's own terminal.
  property string agentId: ""
  property string agentName: ""
  property string lastQuestion: ""
  property bool offerAgentTerminal: false
  readonly property bool busy: request.running

  // Absolute path of a file shipped next to this QML file in the plugin folder.
  function pluginFile(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function open(question) {
    answer = ""
    error = ""
    offerAgentTerminal = false
    if (!agentInfo.running) agentInfo.running = true
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
    offerAgentTerminal = false
    lastQuestion = question
    output = ""
    diagnostics = ""
    elapsed = 0
    cancelled = false
    responseScroll.contentItem.contentY = 0
    request.command = ["bash", pane.pluginFile("answer.sh"), question]
    request.running = true
  }

  // Enter asks; Shift+Enter falls through so the text area inserts a newline.
  function submitKey(event) {
    if (event.modifiers & Qt.ShiftModifier) {
      event.accepted = false
      return
    }
    submit()
    event.accepted = true
  }

  function openInAgent() {
    var question = lastQuestion || questionInput.text.trim()
    if (!question) return
    Quickshell.execDetached(["omarchy", "agent", "prompt", question])
    closeRequested()
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
      pane.offerAgentTerminal = code === 3 && !pane.cancelled
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

  Process {
    id: agentInfo
    command: ["bash", pane.pluginFile("answer.sh"), "--agent-info"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var info = JSON.parse(text)
          pane.agentId = info.id || ""
          pane.agentName = info.name || ""
        } catch (e) {
          pane.agentId = ""
          pane.agentName = ""
        }
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
      text: pane.agentName ? "Ask AI · " + pane.agentName : "Ask AI"
      color: Color.menu.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Long questions wrap onto new lines and the box grows with them, up to a
  // third of the pane; past that it scrolls. Enter asks, Shift+Enter adds a line.
  Controls.ScrollView {
    id: questionScroll
    anchors.top: heading.bottom
    anchors.topMargin: Style.spacing.md
    width: parent.width
    height: Math.min(questionInput.implicitHeight, pane.height / 3)
    contentWidth: availableWidth
    clip: true
    background: Rectangle {
      color: "transparent"
      radius: Style.cornerRadius
      border.width: 1
      border.color: Color.menu.border
    }

    Controls.TextArea {
      id: questionInput
      placeholderText: "Ask a question…"
      color: Color.menu.text
      placeholderTextColor: Qt.alpha(Color.menu.text, 0.5)
      selectionColor: Color.menu.selectedBackground
      selectedTextColor: Color.menu.selectedText
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      padding: Style.space(12)
      wrapMode: TextEdit.Wrap
      textFormat: TextEdit.PlainText
      selectByMouse: true
      readOnly: pane.busy
      background: null
      Keys.onReturnPressed: function(event) { pane.submitKey(event) }
      Keys.onEnterPressed: function(event) { pane.submitKey(event) }
    }
  }

  Text {
    id: status
    anchors.top: questionScroll.bottom
    anchors.topMargin: Style.spacing.md
    width: parent.width
    text: pane.busy ? "Thinking… " + pane.elapsed + "s" : pane.error ? "Unable to answer" : pane.answer ? "Answer" : "Enter to ask · Shift+Enter for a new line · Esc to return to search"
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
      visible: !pane.offerAgentTerminal
      enabled: pane.busy || questionInput.text.trim().length > 0
      onClicked: { if (pane.busy) pane.stop(); else pane.submit() }
    }
    ActionButton {
      text: "Open in " + (pane.agentName || "agent")
      visible: pane.offerAgentTerminal
      onClicked: pane.openInAgent()
    }
    ActionButton {
      text: "Copy answer"
      enabled: pane.answer.length > 0
      onClicked: { response.selectAll(); response.copy(); response.deselect() }
    }
  }
}
