import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons

// Windows 10 Start: rail, all-apps list, live-tile area and power menu.
PopupWindow {
  id: root

  required property var bar
  property Item anchorItem: null
  property bool shown: false
  property string query: ""
  property bool searchMode: false
  property bool expandedRail: false
  property bool powerOpen: false
  property bool weatherOpen: false
  property bool calendarOpen: false
  property date now: new Date()
  property string weatherStatus: ""
  property string weatherTemp: ""
  property string weatherLocation: ""
  signal dismissed()
  signal launchRequested(var entry)
  signal settingsRequested()

  readonly property var appRows: { var q = root.query; return root.buildAppRows() }
  readonly property var recentApps: {
    var result = []
    for (var i = 0; i < root.appRows.length && result.length < 3; i++)
      if (root.appRows[i].type === "app") result.push(root.appRows[i])
    return result
  }
  readonly property var mediaPlayer: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++)
      if (players[i] && (players[i].trackTitle || players[i].isPlaying)) return players[i]
    return players.length > 0 ? players[0] : null
  }
  readonly property var tileGroups: root.buildTileGroups()
  readonly property string initial: (Quickshell.env("USER") || "U").charAt(0).toUpperCase()

  Process {
    id: weatherProc
    command: ["omarchy", "weather", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = String(text || "").trim()
        root.weatherStatus = value
        var parts = value.split("·")
        root.weatherLocation = String(parts[0] || "").trim()
        var match = value.match(/Temp\s+([+-]?[0-9]+\s*°[CF])/i)
        root.weatherTemp = match ? match[1].replace(/\s+/g, " ") : ""
      }
    }
  }
  Timer {
    interval: 900000
    repeat: true
    running: true
    onTriggered: if (!weatherProc.running) weatherProc.running = true
  }
  Component.onCompleted: if (!weatherProc.running) weatherProc.running = true
  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.now = new Date()
  }
  function calendarCells() {
    var year = root.now.getFullYear()
    var month = root.now.getMonth()
    var first = new Date(year, month, 1).getDay()
    var days = new Date(year, month + 1, 0).getDate()
    var cells = []
    for (var i = 0; i < 42; i++) {
      var day = i - first + 1
      cells.push(day >= 1 && day <= days ? day : 0)
    }
    return cells
  }
  function parseWeather() { if (!weatherProc.running) weatherProc.running = true }

  function open(anchor, text, search) {
    anchorItem = anchor
    if (!weatherProc.running) weatherProc.running = true
    query = String(text || "")
    searchMode = search === true
    powerOpen = false
    weatherOpen = false
    calendarOpen = false
    root.shown = true
  }
  function close() {
    if (!root.shown) return
    root.shown = false
    powerOpen = false
    root.dismissed()
  }
  function run(command) {
    if (root.bar) root.bar.run(command)
    root.close()
  }
  function matches(name) {
    return root.query.length === 0 || String(name).toLowerCase().indexOf(root.query.toLowerCase()) >= 0
  }
  function buildAppRows() {
    var entries = DesktopEntries.applications.values.slice()
    entries.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
    var rows = []
    var letter = ""
    var seen = {}
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || entry.noDisplay || !root.matches(entry.name)) continue
      if (seen[entry.name]) continue
      seen[entry.name] = true
      var first = String(entry.name).charAt(0).toUpperCase()
      if (first !== letter) { letter = first; rows.push({ type: "letter", text: letter }) }
      rows.push({ type: "app", name: entry.name, entry: entry })
    }
    return rows
  }
  function buildTiles() {
    var ids = ["org.gnome.Nautilus", "chromium", "foot", "libreoffice-writer",
               "org.gnome.Papers", "mpv", "omawrite", "omacalc"]
    var out = [{ calendar: true, name: "Calendar", color: "#0078d7" },
               { weather: true, name: "Weather", color: "#0078d7" }]
    if (root.mediaPlayer) out.push({ media: true, name: "Now playing", color: "#107c10" })
    for (var i = 0; i < ids.length; i++) {
      var entry = DesktopEntries.byId(ids[i])
      if (!entry || entry.noDisplay) continue
      out.push({ entry: entry, name: entry.name, color: root.tileColor(entry.id) })
    }
    return out
  }
  function buildTileGroups() {
    var all = root.buildTiles()
    var life = [], productivity = [], explore = []
    for (var i = 0; i < all.length; i++) {
      var tile = all[i]
      var id = tile.entry ? String(tile.entry.id) : ""
      if (tile.calendar || tile.weather || id === "org.gnome.Nautilus") life.push(tile)
      else if (id === "libreoffice-writer" || id === "omawrite" || id === "omacalc") productivity.push(tile)
      else explore.push(tile)
    }
    var groups = []
    if (life.length) groups.push({ title: "Life at a glance", tiles: life })
    if (productivity.length) groups.push({ title: "Productivity", tiles: productivity })
    if (explore.length) groups.push({ title: "Explore", tiles: explore })
    return groups
  }
  function tileColor(id) {
    switch (id) {
    case "org.gnome.Nautilus": return "#ffb900"
    case "foot": return "#1b1b1b"
    case "libreoffice-writer": return "#185abd"
    case "org.gnome.Papers": return "#0078d7"
    case "mpv": return "#5c2d91"
    case "omacalc": return "#217346"
    default: return "#0078d7"
    }
  }

  visible: shown || card.opacity > 0
  color: "transparent"
  implicitWidth: 640 + (expandedRail ? 112 : 0)
  implicitHeight: 600
  mask: Region { item: root.shown ? card : null }

  onShownChanged: {
    if (!root.bar) return
    if (shown) root.bar.requestPopout(root)
    else if (root.bar.activePopout === root) root.bar.releasePopout(root)
  }

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
      var popupWidth = root.implicitWidth
      var popupHeight = root.implicitHeight
      var localX = -root.anchorItem.x
      var localY = -popupHeight
      if (root.bar.position === "top") localY = root.anchorItem.height
      else if (root.bar.position === "left") { localX = root.anchorItem.width; localY = -root.anchorItem.y }
      else if (root.bar.position === "right") { localX = -popupWidth; localY = -root.anchorItem.y }
      var win = root.anchorItem.QsWindow.window
      if (!win) return
      var point = win.contentItem.mapFromItem(root.anchorItem, localX, localY)
      popupAnchor.rect.x = Math.round(Math.max(0, Math.min(point.x, win.width - popupWidth)))
      popupAnchor.rect.y = Math.round(Math.max(0, Math.min(point.y, win.height - popupHeight)))
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    color: "#1f1f1f"
    border.width: 1
    border.color: "#4d4d4d"
    property real reveal: root.shown ? 1 : 0
    Behavior on reveal {
      NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }
    opacity: reveal
    scale: 0.99 + 0.01 * reveal
    transformOrigin: root.bar && root.bar.position === "top" ? Item.Top : Item.Bottom

    // Left rail: hamburger, account, folders, settings and power.
    Rectangle {
      id: rail
      width: 48 + (root.expandedRail ? 112 : 0)
      height: parent.height
      color: "#191919"
      Behavior on width { NumberAnimation { duration: 90 } }

      Item {
        id: hamburger
        x: 8; y: 10; width: 32; height: 32
        Column {
          anchors.centerIn: parent
          spacing: 4
          Repeater { model: 3; delegate: Rectangle { width: 16; height: 1.5; color: "#ffffff" } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.expandedRail = !root.expandedRail }
      }
      Text {
        visible: root.expandedRail
        x: 48; anchors.verticalCenter: hamburger.verticalCenter
        text: "Menu"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 13
      }

      Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width
        spacing: 2
        Item {
          width: parent.width; height: 40
          Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "\uf007"; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 18; color: "#ffffff" }
          Text { visible: root.expandedRail; x: 48; anchors.verticalCenter: parent.verticalCenter; text: "Account"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 13 }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsRequested() }
        }
        Repeater {
          model: [
            { icon: "\uf07b", label: "Documents", command: "uwsm-app -- nautilus ~/Documents" },
            { icon: "\uf03e", label: "Pictures", command: "uwsm-app -- nautilus ~/Pictures" },
            { icon: "\uf013", label: "Settings", command: "" }
          ]
          delegate: Item {
            required property var modelData
            width: rail.width; height: 40
            Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 17; color: "#ffffff" }
            Text { visible: root.expandedRail; x: 48; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 13 }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: { if (modelData.command.length > 0) { root.run(modelData.command) } else { root.settingsRequested() } }
            }
          }
        }
        Item {
          width: rail.width; height: 40
          Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "\uf011"; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 17; color: "#ffffff" }
          Text { visible: root.expandedRail; x: 48; anchors.verticalCenter: parent.verticalCenter; text: "Power"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 13 }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.powerOpen = !root.powerOpen }
        }
      }

      // Windows 10 power flyout.
      Rectangle {
        visible: root.powerOpen
        x: rail.width + 8; y: card.height - 190
        width: 200; height: 178
        color: "#2b2b2b"
        border.width: 1; border.color: "#4d4d4d"
        Column {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 1
          Repeater {
            model: [
              { label: "Sleep", command: "systemctl suspend" },
              { label: "Shut down", command: "omarchy system shutdown" },
              { label: "Restart", command: "omarchy system reboot" },
              { label: "Sign out", command: "omarchy system logout" }
            ]
            delegate: Rectangle {
              required property var modelData
              width: parent.width; height: 38; color: powerMouse.containsMouse ? "#3f3f3f" : "transparent"
              Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 13 }
              MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.run(modelData.command) }
            }
          }
        }
      }
    }

    // All-apps list.
    Item {
      id: appList
      x: rail.width
      width: 250
      height: parent.height
      Text {
        x: 16; y: 16
        text: root.searchMode && root.query.length > 0 ? "Search results" : "Recently added"
        color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
      }
      Flickable {
        x: 8; y: 40; width: parent.width - 16; height: parent.height - 48
        clip: true
        contentHeight: appColumn.height
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: appColumn
          width: parent.width
          Repeater {
            model: root.searchMode && root.query.length > 0 ? [] : root.recentApps
            delegate: Item {
              required property var modelData
              width: appColumn.width; height: 32
              Rectangle { anchors.fill: parent; color: recentMouse.containsMouse ? "#3a3a3a" : "transparent" }
              Image {
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: Quickshell.iconPath(modelData.entry.icon, true)
                fillMode: Image.PreserveAspectFit
              }
              Text {
                x: 32; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 38
                text: modelData.name
                color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
                elide: Text.ElideRight
              }
              MouseArea {
                id: recentMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                if (modelData.weather) root.weatherOpen = true
                else if (modelData.calendar) root.calendarOpen = true
                else if (modelData.media && root.mediaPlayer) root.mediaPlayer.togglePlaying()
                else root.launchRequested(modelData.entry)
              }
              }
            }
          }
          Text {
            visible: !(root.searchMode && root.query.length > 0)
            width: parent.width; height: 28
            text: "All apps"
            color: "#0078d7"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
          }
          Repeater {
            model: root.appRows
            delegate: Item {
              required property var modelData
              width: appColumn.width
              height: modelData.type === "letter" ? 24 : 32
              Text {
                visible: modelData.type === "letter"
                x: 8; anchors.verticalCenter: parent.verticalCenter
                text: modelData.type === "letter" ? modelData.text : ""
                color: "#0078d7"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
              }
              Rectangle {
                visible: modelData.type === "app"
                anchors.fill: parent
                color: appRowMouse.containsMouse ? "#3a3a3a" : "transparent"
              }
              Image {
                visible: modelData.type === "app"
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: modelData.type === "app" ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                fillMode: Image.PreserveAspectFit
              }
              Text {
                visible: modelData.type === "app"
                x: 32; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 38
                text: modelData.type === "app" ? modelData.name : ""
                color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
                elide: Text.ElideRight
              }
              MouseArea {
                id: appRowMouse
                anchors.fill: parent
                enabled: modelData.type === "app"
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                if (modelData.weather) root.weatherOpen = true
                else if (modelData.calendar) root.calendarOpen = true
                else if (modelData.media && root.mediaPlayer) root.mediaPlayer.togglePlaying()
                else root.launchRequested(modelData.entry)
              }
              }
            }
          }
        }
      }
    }

    // Live tiles, grouped like Windows 10 Start.
    Item {
      id: tiles
      x: rail.width + 250
      width: parent.width - x
      height: parent.height
      visible: !(root.searchMode && root.query.length > 0)
      Column {
        x: 16; y: 40
        width: parent.width - 28
        spacing: 14
        Repeater {
          model: root.tileGroups
          delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 4
            Text {
              text: modelData.title
              color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
            Grid {
              columns: 3
              columnSpacing: 4
              rowSpacing: 4
              Repeater {
                model: modelData.tiles
                delegate: Rectangle {
                  required property var modelData
                  width: 100; height: 100
                  color: modelData.color
                  border.width: tileMouse.containsMouse ? 1 : 0
                  border.color: "#ffffff"
                  Image {
                    visible: modelData.media === true && root.mediaPlayer && String(root.mediaPlayer.trackArtUrl || "").length > 0
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -14
                    width: 38; height: 38
                    source: root.mediaPlayer ? String(root.mediaPlayer.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                  }
                  Text {
                    visible: modelData.media === true && !(root.mediaPlayer && String(root.mediaPlayer.trackArtUrl || "").length > 0)
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12
                    text: "\uf001"
                    color: "#ffffff"; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 28
                  }
                  Text {
                    visible: modelData.media === true
                    x: 7; y: 58; width: parent.width - 14
                    text: root.mediaPlayer ? (root.mediaPlayer.trackTitle || "Media") : "Media"
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 10
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: modelData.media === true
                    x: 7; y: 70; width: parent.width - 14
                    text: root.mediaPlayer ? (root.mediaPlayer.trackArtist || "") : ""
                    color: "#d8f0d8"; font.family: "Selawik"; font.pixelSize: 9
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: modelData.calendar === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    text: Qt.formatDateTime(root.now, "ddd")
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11
                  }
                  Text {
                    visible: modelData.calendar === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 32
                    text: Qt.formatDateTime(root.now, "d")
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 28; font.weight: Font.Light
                  }
                  Text {
                    visible: modelData.calendar === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 66
                    text: Qt.formatDateTime(root.now, "MMM")
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 10
                  }
                  Image {
                    visible: !modelData.weather && !modelData.calendar && !modelData.media
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8
                    width: 34; height: 34
                    source: modelData.entry ? Quickshell.iconPath(modelData.entry.icon, true) : ""
                    fillMode: Image.PreserveAspectFit
                  }
                  Text {
                    visible: modelData.weather === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    text: root.weatherTemp || "—"
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 24; font.weight: Font.Light
                  }
                  Text {
                    visible: modelData.weather === true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 52
                    width: parent.width - 14
                    text: root.weatherLocation || "Weather"
                    color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: modelData.media !== true
                    x: 7; y: parent.height - 22
                    width: parent.width - 14
                    text: modelData.name
                    color: "#ffffff"
                    font.family: "Selawik"; font.pixelSize: 10
                    elide: Text.ElideRight
                  }
                  MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.weather) root.weatherOpen = true
                      else if (modelData.calendar) root.calendarOpen = true
                      else if (modelData.media && root.mediaPlayer) root.mediaPlayer.togglePlaying()
                      else root.launchRequested(modelData.entry)
                    }
                  }
                }
              }
            }
          }
        }
      }
      Rectangle {
        visible: root.weatherOpen
        x: 16; y: 40
        width: 300; height: 190
        color: "#1f1f1f"
        border.width: 1; border.color: "#4d4d4d"
        Text { x: 16; y: 14; text: "Weather"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 14; font.weight: Font.DemiBold }
        Text { x: 16; y: 42; text: root.weatherLocation || "Weather"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 17 }
        Text { x: 16; y: 70; text: root.weatherTemp || "—"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 34; font.weight: Font.Light }
        Text {
          x: 16; y: 116; width: parent.width - 32
          text: root.weatherStatus
          color: "#b8b8b8"; font.family: "Selawik"; font.pixelSize: 11
          wrapMode: Text.WordWrap
        }
        Rectangle {
          x: 16; y: parent.height - 40; width: 90; height: 27
          color: refreshMouse.containsMouse ? "#3f3f3f" : "#2b2b2b"
          border.width: 1; border.color: "#4d4d4d"
          Text { anchors.centerIn: parent; text: "Refresh"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11 }
          MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.parseWeather() }
        }
        Rectangle {
          anchors.right: parent.right; anchors.rightMargin: 16; y: parent.height - 40; width: 70; height: 27
          color: closeWeatherMouse.containsMouse ? "#3f3f3f" : "#2b2b2b"
          border.width: 1; border.color: "#4d4d4d"
          Text { anchors.centerIn: parent; text: "Close"; color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 11 }
          MouseArea { id: closeWeatherMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.weatherOpen = false }
        }
      }
    }
  }
}
