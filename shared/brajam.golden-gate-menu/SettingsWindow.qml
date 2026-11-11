import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Golden Gate settings use Omarchy's commands; unsupported macOS controls are
// deliberately omitted instead of being presented as working settings.
Item {
  id: root
  property var bar: null
  property bool opened: false
  property string page: "appearance"
  property var config: ({})
  property string opacityMode: "transparent"
  property string search: ""
  property string previousPage: ""
  property var displayState: ({})
  property bool displayRefreshPending: false
  readonly property var dock: config.dock || ({})
  readonly property var focusedDisplay: {
    var list = displayState.monitors || []
    for (var i = 0; i < list.length; i++) if (list[i].focused) return list[i]
    return null
  }
  readonly property real displayScale: focusedDisplay ? focusedDisplay.scale : 0
  // macOS orders its resolution choices as Larger Text, Default, More Space.
  readonly property var displayPresets: [
    { label: "Larger Text", scale: 2.4 },
    { label: "Default", scale: 2 },
    { label: "More Space", scale: 1.6 }
  ]
  readonly property int displayPreset: displayScale >= 2.2 ? 0 : displayScale >= 1.8 ? 1 : 2
  // Omarchy's monitor panel offers these scale presets; keep a custom current
  // scale visible too, so selecting a macOS resolution card never leaves the
  // Scale control without a selected value.
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
  readonly property bool dark: dock.goldenGateDark === true
  readonly property color foreground: dark ? "#f4f4f5" : "#222224"
  readonly property color secondary: dark ? "#a7a7ac" : "#77777c"
  readonly property color canvas: dark ? "#f21d1d1f" : "#f9fafafa"
  readonly property color sidebar: dark ? "#e62a2a2e" : "#f0ececef"
  readonly property color group: dark ? "#39393c" : "#f0f0f1"
  readonly property color separator: dark ? "#505054" : "#dedee0"
  readonly property color accent: "#007aff"
  readonly property int workspaceId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
    ? Hyprland.focusedMonitor.activeWorkspace.id : -1
  readonly property string title: page === "dock" ? "Desktop & Dock" : page === "displays" ? "Displays" : page === "desktop" ? "Workspaces" : page === "wallpaper" ? "Wallpaper" : "Appearance"

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
    command: ["bash", Quickshell.env("HOME") + "/.config/omarchy/themes/macos-2027-golden-gate/display-state.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.displayState = JSON.parse(text) }
        catch (e) { root.displayState = ({}) }
      }
    }
    onExited: if (root.displayRefreshPending) root.refreshDisplays()
  }
  Timer {
    id: displayRefresh
    interval: 700
    repeat: false
    onTriggered: root.refreshDisplays()
  }
  function open(section) {
    root.page = section || "appearance"
    root.opened = true
    root.search = ""
    if (!modeReader.running) modeReader.running = true
    root.refreshDisplays()
    Qt.callLater(function() { keyReceiver.forceActiveFocus() })
  }
  function close() { root.opened = false }
  function navigate(section) {
    if (root.page !== section) { root.previousPage = root.page; root.page = section; content.contentY = 0 }
    if (section === "displays") root.refreshDisplays()
  }
  function refreshDisplays() {
    if (displayReader.running) { root.displayRefreshPending = true; return }
    root.displayRefreshPending = false
    displayReader.running = true
  }
  function run(command) { if (command && root.bar) root.bar.run(command) }
  function chooseMode(mode) { root.opacityMode = mode; root.run("omarchy hyprland window transparency " + mode) }
  function displayScalePreset(scale) { root.run("omarchy hyprland monitor scaling " + scale); displayRefresh.restart() }
  function formatScale(value) { return (Math.round(value * 100) / 100) + "x" }
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
  function dockSize(size) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-size.sh\" " + size) }
  function dockBorder(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-border.sh\" " + value) }
  function dockPositionLock(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-position-lock.sh\" " + value) }
  function darkBorder(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dark-border.sh\" " + value) }
  function menuLogo(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/menu-logo.sh\" " + value) }

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
      border.width: root.dark && root.dock.goldenGateDarkBorders !== true ? 0 : 1
      border.color: root.dark ? "#66666a" : "#c7c7ca"
      clip: true
      MouseArea { anchors.fill: parent; onClicked: keyReceiver.forceActiveFocus() }

      Item {
        id: keyReceiver
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true } }
      }

      Rectangle {
        id: side
        width: 205; height: parent.height
        radius: 12; color: root.sidebar
        Rectangle { x: 12; width: parent.width - 12; height: parent.height; color: root.sidebar }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.separator; opacity: 0.55 }
        Row {
          x: 17; y: 18; spacing: 8
          Repeater {
            model: ["#ff5f57", "#febc2e", "#28c840"]
            delegate: Rectangle {
              required property string modelData
              required property int index
              width: 12; height: 12; radius: 6; color: index === 0 ? modelData : (root.dark ? "#55555a" : "#c6c6c8")
              border.width: 1; border.color: index === 0 ? "#db504b" : color
              MouseArea { anchors.fill: parent; enabled: index === 0; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
          }
        }
        Rectangle {
          x: 12; y: 56; width: parent.width - 24; height: 28; radius: 8
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
              { id: "appearance", title: "Appearance", icon: "\uf042", color: "#66666b" },
              { id: "dock", title: "Desktop & Dock", icon: "\uf108", color: "#515157" },
              { id: "displays", title: "Displays", icon: "\uf109", color: "#3f86e0" },
              { id: "wallpaper", title: "Wallpaper", icon: "\uf03e", color: "#00aac9" },
              { id: "desktop", title: "Workspaces", icon: "\uf00a", color: "#8c76d8" }
            ]
            delegate: Rectangle {
              required property var modelData
              visible: !root.search || modelData.title.toLowerCase().indexOf(root.search.toLowerCase()) >= 0
              width: parent.width; height: visible ? 32 : 0; radius: 7
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
        x: side.width; width: parent.width - side.width; height: parent.height
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
              width: parent.width; spacing: 18; visible: root.page === "appearance"
              Rectangle {
                width: parent.width; height: 119; radius: 10; color: root.group
                Label { x: 14; y: 18; text: "Appearance"; font.pixelSize: 13 }
                Row {
                  anchors.right: parent.right; anchors.rightMargin: 20; y: 14; spacing: 16
                  Repeater {
                    model: [{ name: "Light", dark: false, slug: "macos-2027-golden-gate" }, { name: "Dark", dark: true, slug: "macos-2027-golden-gate-dark" }]
                    delegate: Item {
                      required property var modelData
                      width: 84; height: 91
                      Rectangle {
                        x: 2; y: 1; width: 80; height: 59; radius: 6
                        color: modelData.dark ? "#163460" : "#69b1ef"
                        border.width: root.dark === modelData.dark ? 3 : 1
                        border.color: root.dark === modelData.dark ? root.accent : (root.dark ? "#717175" : "#c8c8cb")
                        Rectangle { x: 5; y: 7; width: 70; height: 4; color: parent.parent.modelData.dark ? "#25345c" : "#d8e6ef" }
                        Rectangle {
                          x: 18; y: 16; width: 55; height: 37; radius: 4
                          color: parent.parent.modelData.dark ? "#303038" : "#f8f8fa"
                          Rectangle { width: parent.width; height: 9; radius: 3; color: parent.parent.parent.modelData.dark ? "#484850" : "#e5e5e8" }
                          Row { x: 5; y: 3; spacing: 2; Repeater { model: ["#ff5f57", "#febc2e", "#28c840"]; delegate: Rectangle { required property string modelData; width: 3; height: 3; radius: 2; color: modelData } } }
                          Rectangle { x: 6; y: 14; width: 17; height: 17; radius: 2; color: parent.parent.parent.modelData.dark ? "#555560" : "#d8d8dd" }
                          Rectangle { x: 27; y: 15; width: 22; height: 3; radius: 1; color: parent.parent.parent.modelData.dark ? "#777780" : "#b4b4bc" }
                          Rectangle { x: 27; y: 22; width: 17; height: 3; radius: 1; color: parent.parent.parent.modelData.dark ? "#696970" : "#ccccd2" }
                        }
                      }
                      Label { y: 67; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.modelData.name; font.pixelSize: 12; font.weight: root.dark === parent.modelData.dark ? Font.DemiBold : Font.Normal }
                      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run("omarchy theme set " + parent.modelData.slug) }
                    }
                  }
                }
              }
              Column {
                width: parent.width; spacing: 7
                Label { x: 10; text: "Windows"; font.weight: Font.DemiBold; font.pixelSize: 13 }
                Rectangle {
                  width: parent.width; height: 110; radius: 10; color: root.group
                  Label { x: 14; y: 17; text: "Window transparency"; font.pixelSize: 13 }
                  Label { x: 14; y: 39; text: "Applies to all Omarchy themes"; color: root.secondary; font.pixelSize: 11 }
                  Segment {
                    x: 14; y: 69; width: parent.width - 28
                    choices: ["Regular", "Frosted Glass", "Opaque"]
                    selectedIndex: root.opacityMode === "glassy" ? 1 : root.opacityMode === "opaque" ? 2 : 0
                    onChosen: function(index) { root.chooseMode(["transparent", "glassy", "opaque"][index]) }
                  }
                }
              }
              Rectangle {
                visible: root.dark
                width: parent.width; height: 72; radius: 10; color: root.group
                Label { x: 14; y: 14; text: "Dark theme outlines"; font.pixelSize: 13 }
                Label { x: 14; y: 36; text: "Windows, Dock and Golden Gate surfaces"; color: root.secondary; font.pixelSize: 11 }
                SwitchControl { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: root.dock.goldenGateDarkBorders === true; onClicked: root.darkBorder(checked ? "off" : "on") }
              }
              Column {
                width: parent.width; spacing: 7
                Label { x: 10; text: "Menu Bar"; font.weight: Font.DemiBold; font.pixelSize: 13 }
                Rectangle {
                  width: parent.width; height: 60; radius: 10; color: root.group
                  Label { x: 14; y: 13; text: "Peanut logo"; font.pixelSize: 13 }
                  Label { x: 14; y: 33; text: "Replaces the Apple mark in the menu bar"; color: root.secondary; font.pixelSize: 11 }
                  SwitchControl { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: root.dock.goldenGateMenuLogo === "peanut"; onClicked: root.menuLogo(checked ? "apple" : "peanut") }
                }
              }
              Rectangle {
                width: parent.width; height: 50; radius: 10; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Wallpaper"; font.pixelSize: 13 }
                Label { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "Choose Wallpaper  ›"; color: root.secondary; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate("wallpaper") }
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "dock"
              Label { x: 10; text: "Dock"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 105; radius: 10; color: root.group
                Label { x: 14; y: 12; text: "Size (three presets)"; font.pixelSize: 13 }
                Label { anchors.right: parent.right; anchors.rightMargin: 14; y: 12; text: root.dock.iconSize === undefined ? "Default" : root.dock.iconSize === 23 ? "Small" : root.dock.iconSize === 29 ? "Medium" : root.dock.iconSize === 38 ? "Large" : String(root.dock.iconSize); color: root.secondary; font.pixelSize: 12 }
                Item {
                  id: sizeTrack
                  x: 17; y: 38; width: parent.width - 34; height: 25
                  readonly property real pos: root.dock.iconSize === 23 ? 0 : root.dock.iconSize === 38 ? 1 : 0.5
                  Rectangle { x: 8; y: 10; width: parent.width - 16; height: 5; radius: 3; color: root.dark ? "#636367" : "#d5d5d8" }
                  Rectangle { x: 8; y: 10; width: (parent.width - 16) * parent.pos; height: 5; radius: 3; color: root.accent }
                  Rectangle { x: 8 + (parent.width - 16) * parent.pos - 9; y: 3; width: 19; height: 19; radius: 10; color: "#fafafa"; border.width: 1; border.color: "#ccccce" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onReleased: function(mouse) { const n = Math.max(0, Math.min(2, Math.round((mouse.x - 8) / (width - 16) * 2))); root.dockSize(["small", "medium", "large"][n]) } }
                }
                Label { x: 14; y: 69; text: "Small"; color: root.secondary; font.pixelSize: 11 }
                Label { anchors.right: parent.right; anchors.rightMargin: 14; y: 69; text: "Large"; color: root.secondary; font.pixelSize: 11 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; y: 70; text: "Reset to Default"; color: root.accent; font.pixelSize: 11; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dockSize("default") } }
              }
              Rectangle {
                width: parent.width; height: 104; radius: 10; color: root.group
                Label { x: 14; y: 17; text: "Dock position on screen"; font.pixelSize: 13 }
                Label { x: 14; y: 40; text: root.dock.positionLocked === true ? "Unlock the Dock to change its position" : "Drag the Dock handle to an edge, or choose below"; color: root.secondary; font.pixelSize: 11 }
                Segment {
                  x: 14; y: 68; width: parent.width - 28
                  enabled: root.dock.positionLocked !== true
                  opacity: enabled ? 1 : 0.45
                  choices: ["Left", "Bottom", "Right", "Top"]
                  selectedIndex: Math.max(0, ["left", "bottom", "right", "top"].indexOf(root.dock.position || "bottom"))
                  onChosen: function(index) { root.run("omarchy dock position " + ["left", "bottom", "right", "top"][index]) }
                }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 10; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Lock Dock position"; font.pixelSize: 13 }
                SwitchControl { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: root.dock.positionLocked === true; onClicked: root.dockPositionLock(checked ? "off" : "on") }
              }
              Rectangle {
                width: parent.width; height: 52; radius: 10; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Automatically hide and show the Dock"; font.pixelSize: 13 }
                SwitchControl { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; checked: root.dock.autohide === true; onClicked: root.run("omarchy dock autohide " + (checked ? "off" : "on")) }
              }
              Rectangle {
                width: parent.width; height: 99; radius: 10; color: root.group
                Label { x: 14; y: 14; text: root.dark ? "Dark theme outlines" : "Dock outline"; font.pixelSize: 13 }
                Label { x: 14; y: 35; text: root.dark ? "Linked with windows and Golden Gate surfaces." : "Light appearance only."; color: root.secondary; font.pixelSize: 11 }
                Segment { x: 14; y: 63; width: parent.width - 28; choices: root.dark ? ["Off", "On"] : ["Off", "On", "Default"]; selectedIndex: root.dark ? (root.dock.goldenGateDarkBorders === true ? 1 : 0) : (root.dock.showBorder === undefined ? 2 : root.dock.showBorder ? 1 : 0); onChosen: function(index) { if (root.dark) root.darkBorder(["off", "on"][index]); else root.dockBorder(["off", "on", "default"][index]) } }
              }
              Label { x: 10; text: "Desktop"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 50; radius: 10; color: root.group
                Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Workspaces and window layout"; font.pixelSize: 13 }
                Label { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: root.secondary; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate("desktop") }
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "displays"
              Rectangle {
                width: parent.width; height: 168; radius: 10; color: root.group
                Item {
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: 16
                  width: 176; height: 100
                  Rectangle {
                    x: 8; y: 0; width: 160; height: 92; radius: 7
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
                    ? root.focusedDisplay.name + "  •  " + Math.round(root.focusedDisplay.width / root.focusedDisplay.scale) + " × " + Math.round(root.focusedDisplay.height / root.focusedDisplay.scale) + "  •  " + Math.round(root.focusedDisplay.refreshRate) + " Hz"
                    : "Waiting for the display"
                }
              }
              Rectangle {
                width: parent.width; height: 122; radius: 10; color: root.group
                Label { x: 14; y: 13; text: "Resolution"; font.pixelSize: 13 }
                Label {
                  anchors.right: parent.right; anchors.rightMargin: 14; y: 14
                  color: root.secondary; font.pixelSize: 11
                  text: root.focusedDisplay ? Math.round(root.focusedDisplay.width / root.focusedDisplay.scale) + " × " + Math.round(root.focusedDisplay.height / root.focusedDisplay.scale) : ""
                }
                Row {
                  x: 14; y: 38; width: parent.width - 28; spacing: 12
                  Repeater {
                    model: root.displayPresets
                    delegate: Item {
                      required property var modelData
                      required property int index
                      width: (parent.width - 24) / 3; height: 70
                      Rectangle {
                        x: 2; width: parent.width - 4; height: 44; radius: 5
                        color: root.dark ? "#2c2c30" : "#f7f7f8"
                        border.width: root.displayPreset === index ? 3 : 1
                        border.color: root.displayPreset === index ? root.accent : (root.dark ? "#5c5c62" : "#d2d2d6")
                        Rectangle {
                          anchors.centerIn: parent; width: parent.width * 0.64; height: 30; radius: 3
                          color: root.dark ? "#46464c" : "#ffffff"
                          border.width: 1; border.color: root.dark ? "#5a5a60" : "#dedee2"
                          Column {
                            anchors.centerIn: parent
                            spacing: index === 0 ? 4 : index === 1 ? 3 : 2
                            Repeater {
                              model: index === 0 ? 3 : index === 1 ? 5 : 7
                              delegate: Rectangle {
                                required property int index
                                width: index === 0 ? 26 : 30
                                height: index === 0 ? 5 : index === 1 ? 3 : 1
                                color: root.dark ? "#98989f" : "#9e9ea6"
                              }
                            }
                          }
                        }
                      }
                      Label {
                        y: 50; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.label; font.pixelSize: 11
                        font.weight: root.displayPreset === parent.index ? Font.DemiBold : Font.Normal
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.displayScalePreset(parent.modelData.scale)
                      }
                    }
                  }
                }
              }
              Rectangle {
                width: parent.width; height: 68; radius: 10; color: root.group
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
                width: parent.width; height: 74; radius: 10; color: root.group
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
                width: parent.width; height: 74; radius: 10; color: root.group
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
                width: parent.width; height: 60; radius: 10; color: root.group
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
                width: parent.width; height: 60; radius: 10; color: root.group
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
                    width: parent.width; height: 52; radius: 10; color: root.group
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
                text: "Resolution changes the whole desktop for this display; Scale and Text size match Omarchy's display panel. Rotation, refresh rate, color profiles, and automatic brightness are not exposed by this display."
                color: root.secondary; font.pixelSize: 11
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "wallpaper"
              Label { x: 10; text: "Wallpaper"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 170; radius: 10; color: root.group
                Image { x: 14; y: 14; width: 210; height: 118; fillMode: Image.PreserveAspectCrop; source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"; cache: false }
                Label { x: 244; y: 24; text: "Golden Gate"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { x: 244; y: 48; text: "Desktop picture"; color: root.secondary; font.pixelSize: 12 }
                SmallButton { x: 244; y: 85; label: "Choose…"; onClicked: { root.close(); root.run("background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\"") } }
                SmallButton { x: 339; y: 85; label: "Next"; onClicked: root.run("omarchy theme bg next") }
              }
            }

            Column {
              width: parent.width; spacing: 10; visible: root.page === "desktop"
              Label { x: 10; text: "Workspaces"; font.weight: Font.DemiBold; font.pixelSize: 13 }
              Rectangle {
                width: parent.width; height: 105; radius: 10; color: root.group
                Label { x: 14; y: 15; text: "Switch workspace"; font.pixelSize: 13 }
                Segment { x: 14; y: 57; width: parent.width - 28; choices: ["1", "2", "3", "4", "5"]; selectedIndex: root.workspaceId - 1; onChosen: function(index) { root.run("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + (index + 1) + "\" })'") } }
              }
              Rectangle {
                width: parent.width; height: 56; radius: 10; color: root.group
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
    width: Math.max(78, buttonText.implicitWidth + 24); height: 27; radius: 6
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
    height: 25; radius: 6; color: root.dark ? "#57575b" : "#dcdcdf"
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
