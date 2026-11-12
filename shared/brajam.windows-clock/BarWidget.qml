import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Windows 10 taskbar clock, action center and the far-right Show desktop strip.
BarWidget {
  id: root
  moduleName: "brajam.windows-clock"

  property date now: new Date()
  property bool actionOpen: false
  property bool wifiOn: false
  property bool bluetoothOn: false
  property bool nightlightOn: false
  property bool dndOn: false
  property int notificationCount: 0
  property var liveNotifications: []
  property var historyNotifications: []
  property var notifications: []

  readonly property string timeText: Qt.formatDateTime(now, "h:mm AP")
  readonly property string dateText: Qt.formatDateTime(now, "M/d/yyyy")

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }
  Process {
    id: wifiReader
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector { onStreamFinished: root.wifiOn = text.trim() === "enabled" }
  }
  Process {
    id: bluetoothReader
    command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]
    stdout: StdioCollector { onStreamFinished: root.bluetoothOn = text.trim() === "on" }
  }
  Process {
    id: nightReader
    command: ["omarchy", "toggle", "nightlight", "--status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.nightlightOn = JSON.parse(text).enabled === true } catch (e) { root.nightlightOn = false }
      }
    }
  }
  Process {
    id: dndReader
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = text.trim()
        root.dndOn = value === "true" || value === "on" || value === "1"
      }
    }
  }
  Process {
    id: countReader
    command: ["omarchy-shell", "notifications", "count"]
    stdout: StdioCollector { onStreamFinished: root.notificationCount = parseInt(text.trim()) || 0 }
  }
  FileView {
    id: liveView
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/live.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var list = JSON.parse(text())
        root.liveNotifications = Array.isArray(list) ? list : []
      } catch (e) {
        root.liveNotifications = []
      }
      root.mergeNotifications()
    }
    onFileChanged: reload()
  }
  FileView {
    id: historyView
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var list = JSON.parse(text())
        root.historyNotifications = Array.isArray(list) ? list : []
      } catch (e) {
        root.historyNotifications = []
      }
      root.mergeNotifications()
    }
    onFileChanged: reload()
  }
  function mergeNotifications() {
    var merged = []
    var seen = ({})
    var sources = root.liveNotifications.concat(root.historyNotifications)
    for (var i = 0; i < sources.length && merged.length < 6; i++) {
      var row = sources[i]
      if (!row || (row.key && seen[row.key])) continue
      if (row.key) seen[row.key] = true
      merged.push(row)
    }
    root.notifications = merged
  }
  Timer { id: actionRefresh; interval: 900; onTriggered: root.refresh() }

  function refresh() {
    if (!wifiReader.running) wifiReader.running = true
    if (!bluetoothReader.running) bluetoothReader.running = true
    if (!nightReader.running) nightReader.running = true
    if (!dndReader.running) dndReader.running = true
    if (!countReader.running) countReader.running = true
  }
  function openActionCenter() {
    root.actionOpen = true
    if (historyView.path !== "") historyView.reload()
    if (liveView.path !== "") liveView.reload()
    root.refresh()
  }
  function closeActionCenter() { root.actionOpen = false }
  function toggleActionCenter() {
    if (root.actionOpen) root.closeActionCenter()
    else root.openActionCenter()
  }
  function quickAction(command) {
    root.bar.run(command)
    actionRefresh.restart()
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
        color: actionMouse.containsMouse || root.actionOpen ? "#26ffffff" : "transparent"
      }
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
        onClicked: root.toggleActionCenter()
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

  PopupWindow {
    id: actionCenter
    anchor {
      id: popupAnchor
      window: actionButton.QsWindow.window
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1
      onAnchoring: {
        if (!actionButton.QsWindow.window || !root.bar) return
        var win = actionButton.QsWindow.window
        var point = win.contentItem.mapFromItem(actionButton, actionButton.width - actionCenter.implicitWidth, -actionCenter.implicitHeight)
        popupAnchor.rect.x = Math.round(Math.max(8, Math.min(point.x, win.width - actionCenter.implicitWidth - 8)))
        popupAnchor.rect.y = Math.round(Math.max(8, point.y))
      }
    }
    visible: root.actionOpen
    color: "transparent"
    implicitWidth: 400
    implicitHeight: 430
    mask: Region { item: root.actionOpen ? panel : null }

    HyprlandFocusGrab {
      active: root.actionOpen
      windows: actionButton.QsWindow.window ? [actionCenter, actionButton.QsWindow.window] : [actionCenter]
      onCleared: root.closeActionCenter()
    }

    Rectangle {
      id: panel
      anchors.fill: parent
      color: "#1f1f1f"
      border.width: 1; border.color: "#4d4d4d"

      Text {
        x: 16; y: 14
        text: "Notifications"
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
      }
      Text {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 14
        text: "Collapse"
        color: collapseMouse.containsMouse ? "#ffffff" : "#b8b8b8"
        font.family: "Selawik"; font.pixelSize: 11
        MouseArea {
          id: collapseMouse
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeActionCenter()
        }
      }

      Flickable {
        x: 16; y: 38
        width: parent.width - 32
        height: 146
        clip: true
        visible: root.notifications.length > 0
        contentHeight: noticeColumn.height
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: noticeColumn
          width: parent.width
          spacing: 1
          Repeater {
          model: root.notifications
          delegate: Rectangle {
            required property var modelData
            width: parent.width; height: 44
            color: notificationMouse.containsMouse ? "#2f2f2f" : "transparent"
            Column {
              x: 4; y: 4; width: parent.width - 60
              Text {
                width: parent.width
                text: modelData.summary || modelData.app || "Notification"
                color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: modelData.body || ""
                color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 11
                elide: Text.ElideRight
              }
            }
            Text {
              anchors.right: parent.right; anchors.rightMargin: 4; y: 4
              text: Qt.formatDateTime(new Date((modelData.ts || 0) * 1000), "h:mm AP")
              color: "#8a8a8a"; font.family: "Selawik"; font.pixelSize: 10
            }
            MouseArea {
              id: notificationMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.closeActionCenter(); root.bar.run("omarchy-shell notifications showHistory") }
            }
          }
          }
        }
      }
      Text {
        visible: root.notifications.length === 0
        x: 16; y: 38
        width: parent.width - 32
        text: root.notificationCount > 0 ? root.notificationCount + " new notification" + (root.notificationCount === 1 ? "" : "s") : "No new notifications"
        color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 12
      }
      Rectangle {
        x: 16; y: 196; width: parent.width - 32; height: 34
        color: historyMouse.containsMouse ? "#3a3a3a" : "#2b2b2b"
        border.width: 1; border.color: "#3f3f3f"
        Text {
          x: 10; anchors.verticalCenter: parent.verticalCenter
          text: "Open notification history"
          color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
        }
        MouseArea {
          id: historyMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.closeActionCenter(); root.bar.run("omarchy-shell notifications showHistory") }
        }
      }

      Text {
        x: 16; y: 244
        text: "Quick actions"
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
      }

      Grid {
        x: 8; y: 282
        columns: 4
        spacing: 4
        Repeater {
          model: [
            { title: "All settings", icon: "\uf013", state: false, command: "omarchy-shell brajam.windows-taskbar settings home" },
            { title: "Network", icon: "\uf1eb", state: root.wifiOn, command: "omarchy-shell shell summon omarchy.network" },
            { title: "Night light", icon: "\uf186", state: root.nightlightOn, command: "omarchy toggle nightlight" },
            { title: "Focus assist", icon: "\uf1f6", state: root.dndOn, command: "omarchy-shell notifications toggleDnd" },
            { title: "Wi-Fi", icon: "\uf1eb", state: root.wifiOn, command: "nmcli radio wifi toggle" },
            { title: "Bluetooth", icon: "\uf293", state: root.bluetoothOn, command: "bluetoothctl power toggle" },
            { title: "Screen snip", icon: "\uf030", state: false, command: "omarchy capture screenshot region" }
          ]
          delegate: Rectangle {
            required property var modelData
            width: 92; height: 62
            color: modelData.state ? "#0078d7" : "#2b2b2b"
            border.width: 1; border.color: modelData.state ? "#0078d7" : "#3f3f3f"
            Text {
              x: 8; y: 8
              text: modelData.icon
              font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 15; color: "#ffffff"
            }
            Text {
              x: 8; y: 36; width: parent.width - 12
              text: modelData.title
              color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11
              elide: Text.ElideRight
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.quickAction(modelData.command)
            }
          }
        }
      }

    }
  }

  ShellIpc {
    target: "brajam.windows-clock"
    function action(): void { root.toggleActionCenter() }
    function close(): void { root.closeActionCenter() }
  }
}
