import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Windows 10 taskbar clock, action center and the far-right Show desktop strip.
BarWidget {
  id: root
  moduleName: "brajam.windows-clock"

  property date now: new Date()

  readonly property string timeText: Qt.formatDateTime(now, "h:mm AP")
  readonly property string dateText: Qt.formatDateTime(now, "M/d/yyyy")

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }
  implicitWidth: 70 + 40 + 6
  implicitHeight: root.barSize

  Row {
    anchors.fill: parent

    Column {
      width: 70
      height: implicitHeight
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      Text {
        width: parent.width; horizontalAlignment: Text.AlignRight
        text: root.timeText
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11
      }
      Text {
        width: parent.width; horizontalAlignment: Text.AlignRight
        text: root.dateText
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11
      }
      anchors.verticalCenterOffset: -1
    }

    Item {
      id: actionButton
      width: 40; height: root.barSize
      Rectangle {
        anchors.fill: parent
        color: actionMouse.containsMouse ? "#26ffffff" : "transparent"
      }
      // speech bubble outline
      Rectangle {
        anchors.centerIn: parent
        width: 18; height: 14
        color: "transparent"
        border.width: 1; border.color: "#ffffff"
        Rectangle { x: 3; y: 13; width: 5; height: 5; rotation: 45; color: "#ffffff" }
      }
      MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.run("omarchy-shell notifications showHistory")
      }
    }

    Rectangle {
      id: showDesktop
      width: 6; height: root.barSize
      color: showMouse.containsMouse ? "#40ffffff" : "transparent"
      MouseArea {
        id: showMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.run("bash \"$HOME/.config/omarchy/themes/windows-10/windows-show-desktop.sh\"")
      }
    }
  }


}
