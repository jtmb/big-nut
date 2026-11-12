import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// A compact Task View: every open window as an icon-and-title card.
PopupWindow {
  id: root

  required property var bar
  property Item anchorItem: null
  property bool shown: false
  signal dismissed()

  function open(anchor) {
    anchorItem = anchor
    root.shown = true
  }
  function close() {
    if (!root.shown) return
    root.shown = false
    root.dismissed()
  }

  readonly property var windows: {
    var result = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var wayland = toplevels[i].wayland
      if (!wayland || wayland.parent) continue
      var entry = DesktopEntries.heuristicLookup(String(wayland.appId || ""))
      var openCode = String(wayland.appId || "") === "org.omarchy.agent"
      result.push({
        title: String(toplevels[i].title || (entry ? entry.name : (openCode ? "OpenCode" : wayland.appId)) || "Window"),
        icon: openCode ? "file:///usr/share/omarchy/shell/plugins/agents/assets/opencode.svg" : (entry ? entry.icon : "application-x-executable"),
        toplevel: toplevels[i]
      })
    }
    return result
  }

  visible: shown || card.opacity > 0
  color: "transparent"
  implicitWidth: 880
  implicitHeight: 460
  mask: Region { item: root.shown ? card : null }

  HyprlandFocusGrab {
    active: root.shown
    windows: root.anchorItem && root.anchorItem.QsWindow.window
      ? [root, root.anchorItem.QsWindow.window] : [root]
    onCleared: root.close()
  }

  anchor {
    id: popupAnchor
    window: root.anchorItem ? root.anchorItem.QsWindow.window : null
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1
    onAnchoring: {
      if (!root.anchorItem || !root.bar) return
      var win = root.anchorItem.QsWindow.window
      if (!win) return
      var point = win.contentItem.mapFromItem(root.anchorItem, 0, -root.implicitHeight - 8)
      popupAnchor.rect.x = Math.round(Math.max(8, (win.width - root.implicitWidth) / 2))
      popupAnchor.rect.y = Math.round(Math.max(8, Math.min(point.y, win.height - root.implicitHeight - root.bar.barSize - 8)))
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    color: "#1f1f1f"
    border.width: 1
    border.color: "#4d4d4d"
    property real reveal: root.shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    opacity: reveal

    Text {
      x: 20; y: 16
      text: "Task View"
      color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 15; font.weight: Font.DemiBold
    }

    Grid {
      x: 20; y: 52
      width: parent.width - 40
      columns: 3
      spacing: 12
      Repeater {
        model: root.windows
        delegate: Rectangle {
          required property var modelData
          width: (card.width - 64) / 3
          height: 150
          color: cardMouse.containsMouse ? "#2f2f2f" : "#262626"
          border.width: 1
          border.color: cardMouse.containsMouse ? "#0078d7" : "#3a3a3a"
          Image {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -18
            width: 40; height: 40
            source: Quickshell.iconPath(modelData.icon, true)
            fillMode: Image.PreserveAspectFit
          }
          Text {
            x: 10; y: parent.height - 42
            width: parent.width - 20
            text: modelData.title
            color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
          MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              modelData.toplevel.activate()
              root.close()
            }
          }
        }
      }
    }

    Text {
      visible: root.windows.length === 0
      anchors.centerIn: parent
      text: "No open windows"
      color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 13
    }
  }
}
