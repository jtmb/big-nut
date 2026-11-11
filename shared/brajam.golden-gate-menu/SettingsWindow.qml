import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui

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
  readonly property var dock: config.dock || ({})
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
  readonly property string title: page === "dock" ? "Desktop & Dock" : page === "desktop" ? "Workspaces" : page === "wallpaper" ? "Wallpaper" : "Appearance"

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
  function open(section) {
    root.page = section || "appearance"
    root.opened = true
    root.search = ""
    if (!modeReader.running) modeReader.running = true
    Qt.callLater(function() { keyReceiver.forceActiveFocus() })
  }
  function close() { root.opened = false }
  function navigate(section) { if (root.page !== section) { root.previousPage = root.page; root.page = section; content.contentY = 0 } }
  function run(command) { if (command && root.bar) root.bar.run(command) }
  function chooseMode(mode) { root.opacityMode = mode; root.run("omarchy hyprland window transparency " + mode) }
  function dockSize(size) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-size.sh\" " + size) }
  function dockBorder(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-border.sh\" " + value) }
  function dockPositionLock(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dock-position-lock.sh\" " + value) }
  function darkBorder(value) { root.run("bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/dark-border.sh\" " + value) }

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
              Label { x: 10; width: parent.width - 20; wrapMode: Text.WordWrap; text: "Workspace 1 retains its scrolling layout while the Dock is visible."; color: root.secondary; font.pixelSize: 11 }
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
