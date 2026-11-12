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
  property var dismissedKeys: ({})
  property bool dismissedPending: false

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
    id: dismissedReader
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/themes/windows-10/notification-dismissed.py", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var rows = JSON.parse(text)
          var map = ({})
          for (var i = 0; i < rows.length; i++) map[String(rows[i])] = true
          root.dismissedKeys = map
          root.mergeNotifications()
        } catch (e) {}
      }
    }
  }
  Process {
    id: dismissedWriter
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/themes/windows-10/notification-dismissed.py", "add"]
    onExited: {
      if (root.dismissedPending) {
        root.dismissedPending = false
        root.persistDismissed()
      } else if (!dismissedReader.running) {
        dismissedReader.running = true
      }
    }
  }
  Component.onCompleted: if (!dismissedReader.running) dismissedReader.running = true
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
      if (!row || (row.key && (seen[row.key] || root.dismissedKeys[row.key]))) continue
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
  function persistDismissed() {
    var keys = []
    for (var key in root.dismissedKeys) keys.push(key)
    if (dismissedWriter.running) { root.dismissedPending = true; return }
    dismissedWriter.command = ["python3", Quickshell.env("HOME") + "/.config/omarchy/themes/windows-10/notification-dismissed.py", "add"].concat(keys)
    dismissedWriter.running = true
  }
  function slug(text) {
    return String(text || "").toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[-.]+|[-.]+$/g, "")
  }
  function notificationIcon(row) {
    if (!row) return ""
    var icon = String(row.appIcon || "")
    var source = String(row.source || "")
    var app = String(row.app || "")
    var names = [icon, source, app, root.slug(icon), root.slug(source), root.slug(app)]
    for (var i = 0; i < names.length; i++) {
      var name = names[i]
      if (!name) continue
      if (name.charAt(0) === "/") return Util.fileUrl(name)
      var found = Quickshell.iconPath(name, true)
      if (found) return found
      var entry = DesktopEntries.heuristicLookup(name)
      if (entry && entry.icon) {
        found = Quickshell.iconPath(entry.icon, true)
        if (found) return found
      }
    }
    return ""
  }
  function glyphFamily(glyph) {
    var code = String(glyph || "").codePointAt(0)
    return code >= 0xe900 && code <= 0xe9ff ? "omarchy" : "JetBrainsMono Nerd Font"
  }
  function dismissNotification(notification) {
    if (!notification) return
    if (notification.key) root.dismissedKeys[notification.key] = true
    var summary = notification.summary ? String(notification.summary) : ""
    if (summary) root.bar.run("omarchy-shell notifications dismiss " + Util.shellQuote(summary))
    root.mergeNotifications()
    root.persistDismissed()
    actionRefresh.restart()
  }
  function activateNotification(notification) {
    if (!notification) return
    var argv = null
    if (notification.execArgv) {
      try {
        argv = typeof notification.execArgv === "string" ? JSON.parse(notification.execArgv) : notification.execArgv
      } catch (e) { argv = null }
    }
    root.closeActionCenter()
    if (argv && argv.length) {
      if (notification.key) root.dismissedKeys[notification.key] = true
      var summary = notification.summary ? String(notification.summary) : ""
      if (summary) root.bar.run("omarchy-shell notifications dismiss " + Util.shellQuote(summary))
      root.mergeNotifications()
      root.persistDismissed()
      Util.execArgv(argv)
      actionRefresh.restart()
      return
    }
    if (notification.link && String(notification.link).length) {
      root.bar.run("xdg-open " + Util.shellQuote(String(notification.link)))
      return
    }
    root.bar.run("omarchy-shell notifications showHistory")
  }
  function clearNotifications() {
    for (var i = 0; i < root.notifications.length; i++) {
      var key = root.notifications[i].key
      if (key) root.dismissedKeys[key] = true
    }
    root.notifications = []
    root.bar.run("omarchy-shell notifications dismissAll")
    root.persistDismissed()
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
      Row {
        anchors.right: parent.right; anchors.rightMargin: 12; y: 14
        spacing: 12
        Text {
          visible: root.notifications.length > 0
          text: "Clear all"
          color: clearMouse.containsMouse ? "#ffffff" : "#b8b8b8"
          font.family: "Selawik"; font.pixelSize: 11
          MouseArea {
            id: clearMouse
            anchors.fill: parent; anchors.margins: -4
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.clearNotifications()
          }
        }
        Text {
          text: "Collapse"
          color: collapseMouse.containsMouse ? "#ffffff" : "#b8b8b8"
          font.family: "Selawik"; font.pixelSize: 11
          MouseArea {
            id: collapseMouse
            anchors.fill: parent; anchors.margins: -4
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.closeActionCenter()
          }
        }
      }

      Flickable {
        x: 8; y: 38
        width: parent.width - 16
        height: 176
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
              width: parent.width; height: 56
              color: notificationMouse.containsMouse ? "#2f2f2f" : "transparent"
              property string iconSource: root.notificationIcon(modelData)

              Rectangle {
                x: 8; y: 8; width: 30; height: 30; radius: 2
                color: "#0078d7"
                Text {
                  anchors.centerIn: parent
                  visible: (modelData.glyph && String(modelData.glyph).length > 0) || notificationIcon.status !== Image.Ready
                  text: modelData.glyph && String(modelData.glyph).length > 0 ? String(modelData.glyph) : "\uf0f3"
                  color: "#ffffff"
                  font.family: modelData.glyph && String(modelData.glyph).length > 0 ? root.glyphFamily(modelData.glyph) : "Font Awesome 7 Free Solid"
                  font.pixelSize: modelData.glyph && String(modelData.glyph).length > 0 ? 16 : 13
                }
                Image {
                  id: notificationIcon
                  anchors.fill: parent
                  visible: !(modelData.glyph && String(modelData.glyph).length > 0) && status === Image.Ready
                  source: parent.parent.iconSource
                  fillMode: Image.PreserveAspectFit
                }
              }
              Column {
                x: 46; y: 8; width: parent.width - 96
                Text {
                  width: parent.width
                  text: modelData.summary || modelData.app || "Notification"
                  color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: modelData.body || String(modelData.app || "")
                  color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 11
                  elide: Text.ElideRight
                }
              }
              Text {
                anchors.right: parent.right; anchors.rightMargin: 24; y: 8
                text: Qt.formatDateTime(new Date((modelData.ts || 0) * 1000), "h:mm AP")
                color: "#8a8a8a"; font.family: "Selawik"; font.pixelSize: 10
              }
              Text {
                z: 2
                anchors.right: parent.right; anchors.rightMargin: 7; y: 6
                text: "×"
                color: dismissMouse.containsMouse ? "#ffffff" : "#9a9a9a"
                font.family: "Selawik"; font.pixelSize: 15
                MouseArea {
                  id: dismissMouse
                  anchors.fill: parent; anchors.margins: -6
                  hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: root.dismissNotification(modelData)
                }
              }
              MouseArea {
                id: notificationMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activateNotification(modelData)
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
      Text {
        x: 16; y: 218
        text: "Notification history"
        color: historyMouse.containsMouse ? "#ffffff" : "#9a9a9a"
        font.family: "Selawik"; font.pixelSize: 11
        MouseArea {
          id: historyMouse
          anchors.fill: parent; anchors.margins: -4
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
