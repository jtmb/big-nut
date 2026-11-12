import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

// Windows 10 tray overflow: an upward chevron with the system tray items in a
// dark flyout. Network, volume and battery stay in their own taskbar slots.
BarWidget {
  id: root
  moduleName: "brajam.windows-tray"

  property bool open: false
  readonly property var items: SystemTray.items.values

  implicitWidth: 24
  implicitHeight: root.barSize

  Rectangle {
    anchors.fill: parent
    color: mouse.containsMouse || root.open ? "#26ffffff" : "transparent"
  }
  Text {
    anchors.centerIn: parent
    text: "\uf077"
    font.family: "Font Awesome 7 Free Solid"
    font.pixelSize: 10
    color: "#ffffff"
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.open = !root.open
  }

  PopupWindow {
    id: popup
    anchor {
      id: popupAnchor
      window: root.QsWindow.window
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1
      onAnchoring: {
        if (!root.QsWindow.window || !root.bar) return
        var win = root.QsWindow.window
        var point = win.contentItem.mapFromItem(root, root.width - popup.implicitWidth, -popup.implicitHeight)
        popupAnchor.rect.x = Math.round(Math.max(8, Math.min(point.x, win.width - popup.implicitWidth - 8)))
        popupAnchor.rect.y = Math.round(Math.max(8, point.y))
      }
    }
    visible: root.open
    color: "transparent"
    implicitWidth: 280
    implicitHeight: 180
    mask: Region { item: root.open ? panel : null }

    HyprlandFocusGrab {
      active: root.open
      windows: root.QsWindow.window ? [popup, root.QsWindow.window] : [popup]
      onCleared: root.open = false
    }

    Rectangle {
      id: panel
      anchors.fill: parent
      color: "#1f1f1f"
      border.width: 1; border.color: "#4d4d4d"
      Text {
        x: 12; y: 10
        text: "System tray"
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
      }
      Column {
        x: 12; y: 36
        width: parent.width - 24
        spacing: 2
        Repeater {
          model: root.items
          delegate: Item {
            required property var modelData
            width: parent.width; height: 32
            Rectangle {
              anchors.fill: parent
              color: itemMouse.containsMouse ? "#3a3a3a" : "transparent"
            }
            Image {
              x: 4; anchors.verticalCenter: parent.verticalCenter
              width: 16; height: 16
              source: modelData.icon
              fillMode: Image.PreserveAspectFit
            }
            Text {
              x: 28; anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 34
              text: modelData.tooltipTitle || modelData.id || "Tray item"
              color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
              elide: Text.ElideRight
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.activate) modelData.activate()
                root.open = false
              }
            }
          }
        }
      }
      Text {
        visible: root.items.length === 0
        anchors.centerIn: parent
        text: "No tray icons"
        color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 12
      }
    }
  }
}
