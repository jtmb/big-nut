import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "OsdModel.js" as OsdModel

// Windows 10-style OSD: a dark vertical card at the top-left for volume and
// brightness, with a compact horizontal card for message-only overlays.
Item {
  id: root

  property bool opened: false
  property string icon: ""
  property string message: ""
  property string iconKey: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1200

  readonly property bool mediaOsd: iconKey.indexOf("media") === 0 || iconKey.indexOf("player") === 0
  readonly property int cardWidth: root.hasProgress ? 76 : Math.max(150, messageRow.implicitWidth + 32)
  readonly property int cardHeight: root.hasProgress ? 232 : 58
  readonly property real fillHeight: root.hasProgress ? Math.max(0, Math.min(1, root.value / root.maxValue)) * 122 : 0

  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var next = OsdModel.stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration, Commons.I18n.formatNumber)
    iconKey = next.iconKey
    maxValue = next.maxValue
    hasProgress = next.hasProgress
    value = next.value
    message = next.message
    icon = next.icon
    duration = next.duration
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value),
           p.max === undefined ? "100" : String(p.max), p.progressText || "",
           p.duration === undefined ? "1200" : String(p.duration))
    } catch (e) {}
  }

  function close() { opened = false }

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  ShellIpc {
    target: "osd"
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-osd"
    mask: Region {}

    BorderSurface {
      id: card
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: Style.space(24)
      anchors.topMargin: Style.space(24)
      width: root.cardWidth
      height: root.cardHeight
      color: "#1f1f1f"
      borderSpec: Border.flat("#4d4d4d", Math.max(1, Style.space(2)))
      radius: 8
      opacity: root.opened ? 1 : 0

      Column {
        visible: root.hasProgress
        anchors.centerIn: parent
        spacing: Style.space(12)
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.icon
          color: "#ffffff"
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }
        Item {
          width: 10
          height: 122
          Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#4d4d4d"
          }
          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.fillHeight
            radius: 4
            color: "#0078d7"
            Behavior on height {
              enabled: root.opened
              NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
            }
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.message
          color: "#ffffff"
          font.family: "Selawik"
          font.pixelSize: 13
        }
      }

      Row {
        id: messageRow
        visible: !root.hasProgress
        anchors.centerIn: parent
        spacing: Style.space(10)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.icon
          color: "#ffffff"
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.message
          color: "#ffffff"
          font.family: "Selawik"
          font.pixelSize: Style.font.title
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }
}
