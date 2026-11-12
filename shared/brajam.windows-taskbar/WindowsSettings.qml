import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Windows 10 Settings use Omarchy's commands; controls without a working
// Linux equivalent are omitted instead of being presented as real settings.
Item {
  id: root
  property var bar: null
  property bool opened: false
  property string page: "home"
  property date now: new Date()
  property bool maximized: false
  property var config: ({})
  property string opacityMode: "transparent"
  property string search: ""
  property string previousPage: ""
  property var displayState: ({})
  property bool displayRefreshPending: false
  property string networkName: ""
  property bool wifiOn: false
  property bool bluetoothOn: false
  property bool cupsOn: false
  readonly property var dock: config.dock || ({})
  readonly property var focusedDisplay: {
    var list = displayState.monitors || []
    for (var i = 0; i < list.length; i++) if (list[i].focused) return list[i]
    return null
  }
  readonly property real displayScale: focusedDisplay ? focusedDisplay.scale : 0
  // Omarchy's monitor panel offers these scale presets; keep a custom current
  // scale visible too, so the Scale control always has a selected value.
  readonly property var scalePresets: [1, 1.25, 1.6, 2, 3, 4]
  readonly property var scaleChoices: {
    var list = scalePresets.slice()
    var current = displayScale
    if (current > 0) {
      var found = false
      for (var i = 0; i < list.length; i++) if (Math.abs(list[i] - current) < 0.01) found = true
      if (!found) { list.push(Math.round(current * 100) / 100); list.sort(function(a, b) { return a - b }) }
    }
    return list
  }
  readonly property int scaleIndex: {
    var best = 0, distance = 1e9
    for (var i = 0; i < scaleChoices.length; i++) {
      var d = Math.abs(scaleChoices[i] - displayScale)
      if (d < distance) { distance = d; best = i }
    }
    return best
  }
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  readonly property int textSizeIndex: {
    var px = displayState.textSize !== null && displayState.textSize !== undefined ? displayState.textSize : 12
    var best = 0, distance = 1e9
    for (var i = 0; i < textSizeStops.length; i++) {
      var d = Math.abs(textSizeStops[i] - px)
      if (d < distance) { distance = d; best = i }
    }
    return best
  }
  readonly property bool brightnessAvailable: displayState.brightness !== null && displayState.brightness !== undefined
  readonly property bool nightlightOn: displayState.nightlight ? displayState.nightlight.enabled === true : false
  readonly property bool dark: false
  readonly property color foreground: "#000000"
  readonly property color secondary: "#767676"
  readonly property color canvas: "#ffffff"
  readonly property color sidebar: "#f2f2f2"
  readonly property color group: "#f2f2f2"
  readonly property color separator: "#e0e0e0"
  readonly property color accent: "#0078d7"
  readonly property int workspaceId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
    ? Hyprland.focusedMonitor.activeWorkspace.id : -1
  readonly property string title: page === "home" ? "Home"
    : page === "system" ? "System"
    : page === "devices" ? "Devices"
    : page === "network" ? "Network & Internet"
    : page === "accounts" ? "Accounts"
    : page === "time" ? "Time & language"
    : page === "privacy" ? "Privacy & security"
    : page === "update" ? "Update & security"
    : page === "dock" ? "Taskbar"
    : page === "displays" ? "Display"
    : page === "desktop" ? "Multitasking"
    : page === "wallpaper" ? "Background"
    : "Personalization"

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.config = JSON.parse(text()) } catch (e) { root.config = ({}) } }
    onFileChanged: reload()
  }
  Process {
    id: modeReader
    command: ["omarchy", "hyprland", "window", "transparency"]
    stdout: StdioCollector { onStreamFinished: root.opacityMode = text.trim() }
  }
  Process {
    id: displayReader
    command: ["bash", Quickshell.env("HOME") + "/.config/omarchy/themes/windows-10/display-state.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.displayState = JSON.parse(text) }
        catch (e) { root.displayState = ({}) }
      }
    }
    onExited: if (root.displayRefreshPending) root.refreshDisplays()
  }
  Process {
    id: networkReader
    command: ["bash", "-c", "nmcli -t -f NAME connection show --active 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: root.networkName = text.trim() }
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
    id: cupsReader
    command: ["bash", "-c", "systemctl is-active cups 2>/dev/null || true"]
    stdout: StdioCollector { onStreamFinished: root.cupsOn = text.trim() === "active" }
  }
  Timer {
    id: displayRefresh
    interval: 700
    repeat: false
    onTriggered: root.refreshDisplays()
  }
  Timer {
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: root.now = new Date()
  }
  function open(section) {
    root.page = section || "home"
    root.opened = true
    root.search = ""
    if (!modeReader.running) modeReader.running = true
    root.refreshDisplays()
    root.refreshSystem()
    Qt.callLater(function() { keyReceiver.forceActiveFocus() })
  }
  function close() { root.opened = false }
  function navigate(section) {
    if (root.page !== section) { root.previousPage = root.page; root.page = section; content.contentY = 0 }
    if (section === "displays") root.refreshDisplays()
    if (section === "system" || section === "devices" || section === "network") root.refreshSystem()
  }
  function refreshSystem() {
    if (!networkReader.running) networkReader.running = true
    if (!wifiReader.running) wifiReader.running = true
    if (!bluetoothReader.running) bluetoothReader.running = true
    if (!cupsReader.running) cupsReader.running = true
  }
  function toggleWifi() { root.run("nmcli radio wifi toggle"); systemRefresh.restart() }
  function toggleBluetooth() { root.run("bluetoothctl power toggle"); systemRefresh.restart() }
  function openNetworkPanel() { root.close(); root.run("omarchy-shell shell summon omarchy.network") }
  function openAudioPanel() { root.close(); root.run("omarchy-shell shell summon omarchy.audio") }
  function openPowerPanel() { root.close(); root.run("omarchy-shell shell summon omarchy.power") }
  function openPrinters() { if (root.cupsOn) root.run("xdg-open http://localhost:631") }
  Timer { id: systemRefresh; interval: 900; onTriggered: root.refreshSystem() }
  function refreshDisplays() {
    if (displayReader.running) { root.displayRefreshPending = true; return }
    root.displayRefreshPending = false
    displayReader.running = true
  }
  function run(command) { if (command && root.bar) root.bar.run(command) }
  function chooseMode(mode) { root.opacityMode = mode; root.run("omarchy hyprland window transparency " + mode) }
  function displayScalePreset(scale) { root.run("omarchy hyprland monitor scaling " + scale); displayRefresh.restart() }
  function formatScale(value) { return Math.round(value * 100) + "%" }
  function setTextSize(index) {
    var i = Math.max(0, Math.min(root.textSizeStops.length - 1, Math.round(index)))
    textSizeSlider.liveValue = i
    root.run("omarchy display text size " + root.textSizeStops[i])
    displayRefresh.restart()
  }
  function setDisplayEnabled(name, enabled) {
    var output = '"' + String(name || "").replace(/[\\"]/g, "\\$&") + '"'
    var expression = "hl.monitor({ output = " + output + ", disabled = " + (enabled ? "true" : "false") + " })"
    root.run("hyprctl eval " + Util.shellQuote(expression))
    displayRefresh.restart()
  }
  function setBrightness(value) {
    if (!root.focusedDisplay) return
    root.run("omarchy brightness display --no-osd --monitor "
      + Util.shellQuote(root.focusedDisplay.name) + " " + Math.round(value) + "%")
    displayRefresh.restart()
  }
  function toggleNightlight() { root.run("omarchy toggle nightlight"); displayRefresh.restart() }
  function setMirror(on) { root.run("omarchy hyprland monitor internal mirror " + (on ? "on" : "off")); displayRefresh.restart() }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "golden-gate-settings"
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      id: card
      width: Math.min(panel.width - 36, 710)
      height: Math.min(panel.height - 36, 580)
      anchors.centerIn: parent
      radius: 12
      color: root.canvas
      border.width: 1
      border.color: "#cccccc"
      clip: true
      MouseArea { anchors.fill: parent; onClicked: keyReceiver.forceActiveFocus() }

      Item {
        id: keyReceiver
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true } }
      }

      Rectangle {
        id: titleBar
        width: parent.width; height: 32
        color: "#f2f2f2"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#d0d0d0" }
        Label { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Row {
          anchors.right: parent.right; anchors.top: parent.top; height: parent.height
          Repeater {
            model: ["min", "max", "close"]
            delegate: Rectangle {
              required property string modelData
              width: 46; height: 32
              color: captionMouse.containsMouse ? (modelData === "close" ? "#e81123" : "#e5e5e5") : "transparent"
              Text {
                anchors.centerIn: parent
                text: modelData === "min" ? "\u2013" : modelData === "max" ? "\u25a1" : "\u00d7"
                color: captionMouse.containsMouse && modelData === "close" ? "#ffffff" : "#000000"
                font.pixelSize: modelData === "max" ? 14 : 15
                font.family: "Selawik"
              }
              MouseArea {
                id: captionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData === "close") root.close()
                  else if (modelData === "min") root.close()
                  else root.maximized = !root.maximized
                }
              }
            }
          }
        }
      }

      Rectangle {
        id: side
        y: 32; width: 205; height: parent.height - 32
        radius: 0; color: root.sidebar
        Rectangle { x: 12; width: parent.width - 12; height: parent.height; color: root.sidebar }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.separator; opacity: 0.55 }
        Rectangle {
          x: 12; y: 56; width: parent.width - 24; height: 28; radius: 2
          color: root.dark ? "#514e52" : "#dedde0"
          border.width: 1; border.color: root.dark ? "#626064" : "#f8f8f8"
          Label { x: 9; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; font.pixelSize: 19; color: root.secondary }
          TextInput {
            x: 31; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter
            color: root.foreground; font.family: "Adwaita Sans"; font.pixelSize: 12
            clip: true; selectByMouse: true; text: root.search
            onTextEdited: root.search = text
            Text { visible: !parent.text; text: "Search"; textFormat: Text.PlainText; color: root.secondary; font: parent.font }
            Keys.onEscapePressed: { root.search = ""; keyReceiver.forceActiveFocus() }
          }
        }
        Column {
          x: 10; y: 104; width: parent.width - 20; spacing: 3
          Repeater {
            model: [
              { id: "home", title: "Home", icon: "\uf015", color: "#0078d7" },
              { id: "system", title: "System", icon: "\uf108", color: "#0078d7" },
              { id: "devices", title: "Devices", icon: "\uf10a", color: "#0078d7" },
              { id: "network", title: "Network & Internet", icon: "\uf1eb", color: "#0078d7" },
              { id: "appearance", title: "Personalization", icon: "\uf042", color: "#0078d7" },
              { id: "accounts", title: "Accounts", icon: "\uf007", color: "#0078d7" },
              { id: "time", title: "Time & language", icon: "\uf017", color: "#0078d7" },
              { id: "privacy", title: "Privacy & security", icon: "\uf3ed", color: "#0078d7" },
              { id: "update", title: "Update & security", icon: "\uf021", color: "#0078d7" }
            ]
            delegate: Rectangle {
              required property var modelData
              visible: !root.search || modelData.title.toLowerCase().indexOf(root.search.toLowerCase()) >= 0
              width: parent.width; height: visible ? 32 : 0; radius: 2
              color: root.page === modelData.id ? root.accent : (navMouse.containsMouse ? (root.dark ? "#48484d" : "#dadadd") : "transparent")
              Rectangle {
                x: 8; width: 22; height: 22; radius: 5; anchors.verticalCenter: parent.verticalCenter
                color: parent.modelData.color
                Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: parent.parent.modelData.icon; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 12; color: "white" }
              }
              Label { x: 39; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.title; color: root.page === parent.modelData.id ? "white" : root.foreground; font.pixelSize: 13 }
              MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(parent.modelData.id) }
            }
          }
        }
      }

      Item {
        x: side.width; y: 32; width: parent.width - side.width; height: parent.height - 32
        Rectangle {
          id: toolbar
          width: parent.width; height: 52; color: "transparent"
          Rectangle {
            x: 12; y: 10; width: 57; height: 31; radius: 16
            color: root.dark ? "#38383a" : "#f3f3f4"
            border.width: 1; border.color: root.dark ? "#4c4c50" : "#e5e5e6"
            Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "‹"; font.pixelSize: 24; color: root.previousPage ? root.foreground : root.secondary }
            Rectangle { x: 28; y: 7; width: 1; height: 17; color: root.separator }
            Label { x: 36; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: 24; color: root.secondary }
            MouseArea { anchors.left: parent.left; width: 28; height: parent.height; enabled: !!root.previousPage; onClicked: root.navigate(root.previousPage) }
          }
          Label { x: 82; anchors.verticalCenter: parent.verticalCenter; text: root.title; font.pixelSize: 14; font.weight: Font.DemiBold }
        }

        Flickable {
          id: content
          x: 12; y: toolbar.height; width: parent.width - 20; height: parent.height - toolbar.height - 10
          clip: true; contentWidth: width; contentHeight: pages.height
          boundsBehavior: Flickable.StopAtBounds
          Column {
            id: pages
            width: content.width - 8; spacing: 18

            Column {
              width: parent.width; spacing: 18; visible: root.page === "home"
              Label { x: 10; text: "Windows 10"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 92; radius: 2; color: root.group
                Label { x: 14; y: 16; text: "Windows 10"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { x: 14; y: 40; text: "Light mode · default blue accent"; color: root.secondary; font.pixelSize: 12 }
                Rectangle { x: 14; y: 62; width: 20; height: 20; color: "#0078d7" }
                Label { x: 42; y: 64; text: "#0078d7"; font.pixelSize: 12 }
              }
              Label { x: 10; text: "System"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Column {
                width: parent.width; spacing: 1
                Repeater {
                  model: [
                    { title: "Display", detail: "Scale, text size, brightness and Night Shift", target: "displays" },
                    { title: "Sound", detail: "Output, volume and applications", command: "omarchy-shell shell summon omarchy.audio" },
                    { title: "Power & battery", detail: "Battery, power profiles and system information", command: "omarchy-shell shell summon omarchy.power" },
                    { title: "Notifications", detail: "Notification history", command: "omarchy-shell notifications showHistory" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 56; radius: 2; color: root.group
                    Label { x: 14; y: 10; text: modelData.title; font.pixelSize: 13 }
                    Label { x: 14; y: 31; text: modelData.detail; color: root.secondary; font.pixelSize: 11 }
                    Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.secondary; font.pixelSize: 18 }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (modelData.target) root.navigate(modelData.target)
                        else { root.close(); root.run(modelData.command) }
                      }
                    }
                  }
                }
              }
              Label { x: 10; text: "Personalization"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Column {
                width: parent.width; spacing: 1
                Repeater {
                  model: [
                    { title: "Colors and appearance", detail: "Transparency and Windows 10 surfaces", target: "appearance" },
                    { title: "Background", detail: "Desktop wallpaper", target: "wallpaper" },
                    { title: "Taskbar", detail: "Screen edge and taskbar behavior", target: "dock" },
                    { title: "Multitasking", detail: "Workspaces and window layout", target: "desktop" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 56; radius: 2; color: root.group
                    Label { x: 14; y: 10; text: modelData.title; font.pixelSize: 13 }
                    Label { x: 14; y: 31; text: modelData.detail; color: root.secondary; font.pixelSize: 11 }
                    Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.secondary; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(modelData.target) }
                  }
                }
              }
              Label { x: 10; text: "Network & Internet"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Wi-Fi and network"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Open Omarchy's network panel"; color: root.secondary; font.pixelSize: 11 }
                Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.secondary; font.pixelSize: 18 }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: { root.close(); root.run("omarchy-shell shell summon omarchy.network") }
                }
              }
              Label { x: 10; text: "Accounts and system"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Column {
                width: parent.width; spacing: 1
                Repeater {
                  model: [
                    { title: "Accounts", detail: "User, sign out and lock screen", target: "accounts" },
                    { title: "Time & language", detail: "Time zone, date and language", target: "time" },
                    { title: "Privacy & security", detail: "Notifications, Focus assist and lock", target: "privacy" },
                    { title: "Update & security", detail: "Omarchy and theme updates", target: "update" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 56; radius: 2; color: root.group
                    Label { x: 14; y: 10; text: modelData.title; font.pixelSize: 13 }
                    Label { x: 14; y: 31; text: modelData.detail; color: root.secondary; font.pixelSize: 11 }
                    Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.secondary; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(modelData.target) }
                  }
                }
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "system"
              Label { x: 10; text: "System"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 86; radius: 2; color: root.group
                Label { x: 14; y: 14; text: "Display"; font.pixelSize: 13 }
                Label {
                  x: 14; y: 36; width: parent.width - 150
                  text: root.focusedDisplay
                    ? (root.focusedDisplay.internal ? "Built-in Display" : (root.focusedDisplay.description || root.focusedDisplay.name)) + "  ·  " + Math.round(root.focusedDisplay.width) + " × " + Math.round(root.focusedDisplay.height)
                    : "Waiting for the display"
                  color: root.secondary; font.pixelSize: 11; elide: Text.ElideRight
                }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Display settings"; onClicked: root.navigate("displays") }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Sound"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Output, volume and applications"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: root.openAudioPanel() }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Power & battery"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Battery, power profiles and system information"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: root.openPowerPanel() }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Notifications & actions"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Notification history and Focus assist"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: { root.close(); root.run("omarchy-shell notifications showHistory") } }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Multitasking"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Workspaces and window layout"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: root.navigate("desktop") }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "About"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Device name and Windows 10 theme details"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: { root.close(); root.run("omarchy-launch-about") } }
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "devices"
              Label { x: 10; text: "Devices"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 76; radius: 2; color: root.group
                Label { x: 14; y: 14; text: "Bluetooth & other devices"; font.pixelSize: 13 }
                Label { x: 14; y: 38; text: root.bluetoothOn ? "Bluetooth is on" : "Bluetooth is off"; color: root.secondary; font.pixelSize: 11 }
                SmallButton {
                  anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                  label: root.bluetoothOn ? "Turn off" : "Turn on"
                  onClicked: root.toggleBluetooth()
                }
              }
              Rectangle {
                width: parent.width; height: 76; radius: 2; color: root.group
                Label { x: 14; y: 14; text: "Printers & scanners"; font.pixelSize: 13 }
                Label {
                  x: 14; y: 38
                  text: root.cupsOn ? "CUPS is running — manage printers in the web interface" : "CUPS is not running; no printers are available"
                  color: root.secondary; font.pixelSize: 11
                }
                SmallButton {
                  anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                  label: "Open"; enabled: root.cupsOn
                  onClicked: root.openPrinters()
                }
              }
              Label {
                x: 10; width: parent.width - 20; wrapMode: Text.WordWrap
                text: "Mouse, typing, pen and USB settings are provided by the hardware tools on this system; Windows-only device pages are omitted instead of being shown as dead controls."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "network"
              Label { x: 10; text: "Network & Internet"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 86; radius: 2; color: root.group
                Label { x: 14; y: 14; text: "Status"; font.pixelSize: 13 }
                Label {
                  x: 14; y: 38; width: parent.width - 28
                  text: root.wifiOn ? ("Wi-Fi is on" + (root.networkName ? "  ·  " + root.networkName : "")) : "Wi-Fi is off"
                  color: root.secondary; font.pixelSize: 11; elide: Text.ElideRight
                }
                SmallButton {
                  anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                  label: root.wifiOn ? "Turn off" : "Turn on"
                  onClicked: root.toggleWifi()
                }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Network settings"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "Choose a network, VPN and connection details"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: root.openNetworkPanel() }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; y: 10; text: "Proxy"; font.pixelSize: 13 }
                Label { x: 14; y: 31; text: "System proxy is managed by the desktop environment"; color: root.secondary; font.pixelSize: 11 }
              }
              Label {
                x: 10; width: parent.width - 20; wrapMode: Text.WordWrap
                text: "Wi-Fi state comes from NetworkManager and the connection name from the active nmcli connection."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "accounts"
              Label { x: 10; text: "Accounts"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 92; radius: 2; color: root.group
                Rectangle { x: 14; y: 20; width: 52; height: 52; radius: 26; color: "#0078d7" }
                Text { x: 14; y: 20; width: 52; height: 52; text: Quickshell.env("USER").charAt(0).toUpperCase(); color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                Label { x: 80; y: 24; text: Quickshell.env("USER"); font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { x: 80; y: 48; text: "Local account"; color: root.secondary; font.pixelSize: 12 }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "About this computer"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: { root.close(); root.run("omarchy-launch-about") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Lock screen"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Lock"; onClicked: { root.close(); root.run("omarchy system lock") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Sign out"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Sign out"; onClicked: { root.close(); root.run("omarchy system logout") } }
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "time"
              Label { x: 10; text: "Time & language"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 86; radius: 2; color: root.group
                Label { x: 14; y: 16; text: "Date & time"; font.pixelSize: 13 }
                Label { x: 14; y: 40; text: Qt.formatDateTime(root.now, "dddd, MMMM d, yyyy  ·  h:mm AP"); font.pixelSize: 15; font.weight: Font.DemiBold }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Time zone"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Choose"; onClicked: { root.close(); root.run("omarchy menu timezone") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Show current time"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Notify"; onClicked: root.run("omarchy notification time") }
              }
              Label { x: 10; width: parent.width - 20; wrapMode: Text.WordWrap; text: "Language and locale can be changed from Omarchy's language command; this page keeps the Windows 10 date/time controls."; color: root.secondary; font.pixelSize: 11 }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "privacy"
              Label { x: 10; text: "Privacy & security"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Notification history"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Open"; onClicked: { root.close(); root.run("omarchy-shell notifications showHistory") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Focus assist"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Toggle"; onClicked: root.run("omarchy-shell notifications toggleDnd") }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Lock screen"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Lock"; onClicked: { root.close(); root.run("omarchy system lock") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Crash capture"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Toggle"; onClicked: root.run("omarchy toggle crash capture") }
              }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "update"
              Label { x: 10; text: "Update & security"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 76; radius: 2; color: root.group
                Label { x: 14; y: 16; text: "Windows Update"; font.pixelSize: 13 }
                Label { x: 14; y: 40; text: "Omarchy and system packages"; color: root.secondary; font.pixelSize: 11 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Check"; onClicked: { root.close(); root.run("omarchy update") } }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Theme updates"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Update"; onClicked: root.run("omarchy theme update") }
              }
              Label { x: 10; width: parent.width - 20; wrapMode: Text.WordWrap; text: "Updates are provided by Omarchy; no Windows Update service is present."; color: root.secondary; font.pixelSize: 11 }
            }

            Column {
              width: parent.width; spacing: 18; visible: root.page === "appearance"
              Rectangle {
                width: parent.width; height: 92; radius: 2; color: root.group
                Label { x: 14; y: 16; text: "Windows 10"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { x: 14; y: 40; text: "Light app mode"; color: root.secondary; font.pixelSize: 12 }
                Rectangle { x: 14; y: 62; width: 20; height: 20; color: "#0078d7" }
                Label { x: 42; y: 64; text: "Default blue accent (#0078d7)"; font.pixelSize: 12 }
              }
              Rectangle {
                width: parent.width; height: 50; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Background"; font.pixelSize: 13 }
                Label { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "Choose a picture  ›"; color: root.secondary; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate("wallpaper") }
              }
              Column {
                width: parent.width; spacing: 7
                Label { x: 10; text: "Effects"; font.weight: Font.DemiBold; font.pixelSize: 13 }
                Rectangle {
                  width: parent.width; height: 60; radius: 2; color: root.group
                  Label { x: 14; y: 13; text: "Transparency effects"; font.pixelSize: 13 }
                  Label { x: 14; y: 33; text: "Make windows and surfaces slightly translucent"; color: root.secondary; font.pixelSize: 11 }
                  SwitchControl { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: root.opacityMode !== "opaque"; onClicked: root.chooseMode(checked ? "opaque" : "transparent") }
                }
              }
              Label {
                x: 10; width: parent.width - 20; wrapMode: Text.WordWrap
                text: "The Windows 10 appearance uses light app surfaces, square corners and the default blue accent. Transparency is Omarchy's global window setting."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "dock"
              Label { x: 10; text: "Taskbar"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 104; radius: 2; color: root.group
                Label { x: 14; y: 17; text: "Taskbar position on screen"; font.pixelSize: 13 }
                Label { x: 14; y: 40; text: "Choose the screen edge for the Windows taskbar"; color: root.secondary; font.pixelSize: 11 }
                Segment {
                  x: 14; y: 68; width: parent.width - 28
                  choices: ["Left", "Bottom", "Right", "Top"]
                  selectedIndex: Math.max(0, ["left", "bottom", "right", "top"].indexOf((root.config.bar || {}).position || "bottom"))
                  onChosen: function(index) { root.run("omarchy bar position " + ["left", "bottom", "right", "top"][index]) }
                }
              }
              Rectangle {
                width: parent.width; height: 58; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Taskbar buttons"; font.pixelSize: 13 }
                Label { x: 14; y: 33; text: "Windows 10: 40px bar, 24px icons, tray overflow, two-line clock"; color: root.secondary; font.pixelSize: 11 }
              }
              Label {
                x: 10; width: parent.width - 20; wrapMode: Text.WordWrap
                text: "Open apps show a blue underline; running apps keep a gray one. Clicking the active app minimizes it."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "displays"
              Rectangle {
                width: parent.width; height: 168; radius: 2; color: root.group
                Item {
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: 16
                  width: 176; height: 100
                  Rectangle {
                    x: 8; y: 0; width: 160; height: 92; radius: 2
                    color: root.dark ? "#0c0c10" : "#2c2c31"
                    border.width: 1; border.color: root.dark ? "#4b4b52" : "#8b8b92"
                    Rectangle {
                      anchors.fill: parent; anchors.margins: 5; radius: 3
                      color: root.dark ? "#1b1b20" : "#4b4b52"
                      clip: true
                      Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
                        cache: false
                      }
                    }
                  }
                  Rectangle {
                    x: 0; y: 95; width: 176; height: 5; radius: 3
                    color: root.dark ? "#5b5b62" : "#c9c9ce"
                  }
                }
                Label {
                  y: 124; width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: root.focusedDisplay ? (root.focusedDisplay.internal ? "Built-in Display" : (root.focusedDisplay.description || root.focusedDisplay.name)) : "Display"
                  font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Label {
                  y: 145; width: parent.width; horizontalAlignment: Text.AlignHCenter
                  color: root.secondary; font.pixelSize: 11
                  text: root.focusedDisplay
                    ? root.focusedDisplay.name + "  •  " + Math.round(root.focusedDisplay.width) + " × " + Math.round(root.focusedDisplay.height) + "  •  " + Math.round(root.focusedDisplay.scale * 100) + "%  •  " + Math.round(root.focusedDisplay.refreshRate) + " Hz"
                    : "Waiting for the display"
                }
              }
              Rectangle {
                width: parent.width; height: 68; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Scale"; font.pixelSize: 13 }
                Label {
                  anchors.right: parent.right; anchors.rightMargin: 14; y: 14
                  color: root.secondary; font.pixelSize: 11
                  text: root.displayScale > 0 ? root.formatScale(root.displayScale) : ""
                }
                Segment {
                  x: 14; y: 34; width: parent.width - 28
                  choices: root.scaleChoices.map(root.formatScale)
                  selectedIndex: root.scaleIndex
                  onChosen: function(index) { root.displayScalePreset(root.scaleChoices[index]) }
                }
              }
              Rectangle {
                width: parent.width; height: 74; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Text size"; font.pixelSize: 13 }
                Label {
                  anchors.right: parent.right; anchors.rightMargin: 16; y: 14
                  color: root.secondary; font.pixelSize: 11
                  text: root.textSizeStops[Math.round(textSizeSlider.liveValue)] + " px"
                }
                SliderControl {
                  id: textSizeSlider
                  x: 14; y: 38; width: parent.width - 28
                  minimum: 0; maximum: root.textSizeStops.length - 1
                  value: root.textSizeIndex
                  onReleased: function(value) { root.setTextSize(value) }
                }
              }
              Rectangle {
                visible: root.brightnessAvailable
                width: parent.width; height: 74; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Brightness"; font.pixelSize: 13 }
                Label {
                  anchors.right: parent.right; anchors.rightMargin: 16; y: 14
                  color: root.secondary; font.pixelSize: 11
                  text: Math.round(brightnessSlider.liveValue) + "%"
                }
                Text {
                  x: 16; y: brightnessSlider.y + (brightnessSlider.height - height) / 2
                  textFormat: Text.PlainText; text: "\uf185"
                  font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 11
                  color: root.secondary
                }
                Text {
                  anchors.right: parent.right; anchors.rightMargin: 16
                  y: brightnessSlider.y + (brightnessSlider.height - height) / 2
                  textFormat: Text.PlainText; text: "\uf185"
                  font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 16
                  color: root.secondary
                }
                SliderControl {
                  id: brightnessSlider
                  x: 36; y: 38; width: parent.width - 72
                  minimum: 1; maximum: 100
                  value: root.brightnessAvailable ? root.displayState.brightness : 0
                  onReleased: function(value) { root.setBrightness(value) }
                }
              }
              Rectangle {
                width: parent.width; height: 60; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Night Shift"; font.pixelSize: 13 }
                Label { x: 14; y: 33; text: "Warm the display color at night"; color: root.secondary; font.pixelSize: 11 }
                SwitchControl {
                  anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                  checked: root.nightlightOn
                  onClicked: root.toggleNightlight()
                }
              }
              Rectangle {
                visible: root.displayState.external === true
                width: parent.width; height: 60; radius: 2; color: root.group
                Label { x: 14; y: 13; text: "Mirror built-in display"; font.pixelSize: 13 }
                Label { x: 14; y: 33; text: "Show the same image on both displays"; color: root.secondary; font.pixelSize: 11 }
                SwitchControl {
                  anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                  checked: root.displayState.mirror === true
                  onClicked: root.setMirror(checked === false)
                }
              }
              Column {
                visible: (root.displayState.monitors || []).length > 1
                width: parent.width; spacing: 7
                Label { x: 10; text: "Displays"; font.weight: Font.DemiBold; font.pixelSize: 13 }
                Repeater {
                  model: root.displayState.monitors || []
                  delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 52; radius: 2; color: root.group
                    Label {
                      x: 14; anchors.verticalCenter: parent.verticalCenter
                      text: modelData.internal ? "Built-in Display" : (modelData.description || modelData.name)
                      font.pixelSize: 13
                    }
                    SwitchControl {
                      anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                      checked: modelData.enabled
                      enabled: !(modelData.enabled && root.displayState.enabledCount <= 1)
                      opacity: enabled ? 1 : 0.45
                      onClicked: root.setDisplayEnabled(modelData.name, modelData.enabled)
                    }
                  }
                }
              }
              Label {
                x: 10; width: parent.width - 20; wrapMode: Text.WordWrap
                text: "Scale changes the size of text, apps and other items. Rotation, resolution, color profiles and automatic brightness are managed by Hyprland and are not exposed here."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "wallpaper"
              Label { x: 10; text: "Wallpaper"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 170; radius: 2; color: root.group
                Image { x: 14; y: 14; width: 210; height: 118; fillMode: Image.PreserveAspectCrop; source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"; cache: false }
                Label { x: 244; y: 24; text: "Windows 10"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { x: 244; y: 48; text: "Windows 10 wallpaper"; color: root.secondary; font.pixelSize: 12 }
                SmallButton { x: 244; y: 85; label: "Choose…"; onClicked: { root.close(); root.run("background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\"") } }
                SmallButton { x: 339; y: 85; label: "Next"; onClicked: root.run("omarchy theme bg next") }
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "desktop"
              Label { x: 10; text: "Workspaces"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 105; radius: 2; color: root.group
                Label { x: 14; y: 15; text: "Switch workspace"; font.pixelSize: 13 }
                Segment { x: 14; y: 57; width: parent.width - 28; choices: ["1", "2", "3", "4", "5"]; selectedIndex: root.workspaceId - 1; onChosen: function(index) { root.run("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + (index + 1) + "\" })'") } }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 2; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Window layout"; font.pixelSize: 13 }
                SmallButton { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; label: "Cycle Layout"; onClicked: root.run("omarchy hyprland workspace layout toggle") }
              }
              Label { x: 10; width: parent.width - 20; wrapMode: Text.WordWrap; text: "Workspaces use Omarchy's default dwindle layout; Cycle Layout changes the current workspace."; color: root.secondary; font.pixelSize: 11 }
            }
          }
          Rectangle { anchors.right: parent.right; width: 4; radius: 2; visible: content.contentHeight > content.height; height: Math.max(35, content.height * content.height / content.contentHeight); y: content.contentY * (content.height - height) / Math.max(1, content.contentHeight - content.height); color: root.secondary; opacity: 0.6 }
        }
      }
    }
  }

  component Label: Text { textFormat: Text.PlainText; color: root.foreground; font.family: "Adwaita Sans"; font.pixelSize: 13 }
  component SmallButton: Rectangle {
    id: button
    property string label: ""
    signal clicked()
    width: Math.max(78, buttonText.implicitWidth + 24); height: 27; radius: 2
    color: root.dark ? "#5b5b60" : "#ffffff"
    border.width: 1; border.color: root.dark ? "#69696e" : "#d4d4d8"
    Label { id: buttonText; anchors.centerIn: parent; text: button.label; font.pixelSize: 12 }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
  }
  component SwitchControl: Rectangle {
    id: toggle
    property bool checked: false
    signal clicked()
    width: 38; height: 22; radius: 11; color: checked ? root.accent : (root.dark ? "#67676a" : "#d1d1d3")
    Rectangle { x: toggle.checked ? 18 : 2; y: 2; width: 18; height: 18; radius: 9; color: "white"; border.width: 1; border.color: "#dddddf" }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggle.clicked() }
  }
  component SliderControl: Item {
    id: slider
    property real minimum: 0
    property real maximum: 100
    property real value: 0
    property real liveValue: value
    signal released(real value)
    implicitHeight: 24
    readonly property real fraction: Math.max(0, Math.min(1, (liveValue - minimum) / Math.max(0.0001, maximum - minimum)))
    readonly property real trackLeft: 9
    readonly property real trackWidth: Math.max(1, width - 18)
    onValueChanged: if (!mouse.pressed) liveValue = value
    function handle(x) {
      var f = Math.max(0, Math.min(1, (x - trackLeft) / trackWidth))
      liveValue = minimum + f * (maximum - minimum)
    }
    Rectangle {
      x: slider.trackLeft; y: (parent.height - 5) / 2
      width: slider.trackWidth; height: 5; radius: 3
      color: root.dark ? "#636367" : "#d5d5d8"
    }
    Rectangle {
      x: slider.trackLeft; y: (parent.height - 5) / 2
      width: slider.trackWidth * slider.fraction; height: 5; radius: 3
      color: root.accent
    }
    Rectangle {
      x: slider.trackLeft + slider.trackWidth * slider.fraction - 9; y: 3
      width: 18; height: 18; radius: 9
      color: "#fafafa"; border.width: 1; border.color: "#ccccce"
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: slider.handle(mouse.x)
      onPositionChanged: if (pressed) slider.handle(mouse.x)
      onReleased: slider.released(slider.liveValue)
    }
  }
  component Segment: Rectangle {
    id: segment
    property var choices: []
    property int selectedIndex: 0
    signal chosen(int index)
    height: 25; radius: 2; color: root.dark ? "#57575b" : "#dcdcdf"
    Row {
      anchors.fill: parent; anchors.margins: 2
      Repeater {
        model: segment.choices
        delegate: Rectangle {
          required property string modelData
          required property int index
          width: (segment.width - 4) / Math.max(1, segment.choices.length); height: segment.height - 4; radius: 5
          color: segment.selectedIndex === index ? (root.dark ? "#818185" : "#ffffff") : "transparent"
          Label { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 11; font.weight: segment.selectedIndex === parent.index ? Font.DemiBold : Font.Normal }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: segment.chosen(parent.index) }
        }
      }
    }
  }
}
