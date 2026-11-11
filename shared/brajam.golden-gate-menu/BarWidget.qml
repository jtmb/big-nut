import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "brajam.golden-gate-menu"

  property string activeMenu: "apple"
  property bool popupOpen: false
  property Item selectedButton: null
  property var shellConfig: ({})
  // The Big Nut peanut mark keeps the Apple logo's monochrome silhouette
  // treatment while using the theme's own pod artwork.
  readonly property bool peanutLogo: (shellConfig.dock || {}).goldenGateMenuLogo === "peanut"
  function close() { popupOpen = false; settingsWindow.close() }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.shellConfig = JSON.parse(text()) } catch (e) { root.shellConfig = ({}) } }
    onFileChanged: reload()
  }

  // These are working Linux actions, not fake native Finder menus.
  readonly property var titles: [
    { id: "apple", text: "\uf179" }, { id: "finder", text: "Finder" },
    { id: "file", text: "File" }, { id: "edit", text: "Edit" },
    { id: "view", text: "View" }, { id: "go", text: "Go" },
    { id: "window", text: "Window" }, { id: "help", text: "Help" },
    { id: "settings", text: "Settings" }, { id: "dock", text: "Dock" }
  ]
  readonly property var entries: ({
    apple: [
      { title: "About this computer", command: "omarchy-launch-about" },
      { title: "System Settings…", command: "omarchy-shell brajam.golden-gate-menu show settings" },
      { title: "Omarchy Setup…", command: "omarchy menu toggle setup" },
      { title: "Appearance…", command: "omarchy-shell brajam.golden-gate-menu show settings" },
      { title: "", command: "" },
      { title: "Recent Items", command: "uwsm-app -- nautilus recent:///" },
      { title: "Applications", command: "omarchy-shell omarchy.dock apps" },
      { title: "", command: "" },
      { title: "Lock Screen", command: "omarchy system lock" }
    ],
    finder: [
      { title: "Open Files", command: "uwsm-app -- nautilus" },
      { title: "System Settings…", command: "omarchy-shell brajam.golden-gate-menu show settings" },
      { title: "", command: "" },
      { title: "New Finder Window", command: "uwsm-app -- nautilus" },
      { title: "Home", command: "uwsm-app -- nautilus ~" },
      { title: "Downloads", command: "uwsm-app -- nautilus ~/Downloads" }
    ],
    file: [
      { title: "New Window", command: "uwsm-app -- nautilus" },
      { title: "Open Home", command: "uwsm-app -- nautilus ~" },
      { title: "Open Downloads", command: "uwsm-app -- nautilus ~/Downloads" },
      { title: "Open Browser", command: "omarchy launch browser" }
    ],
    edit: [
      { title: "Clipboard History…", command: "omarchy menu clipboard" },
      { title: "Emoji & Symbols…", command: "omarchy menu emoji" },
      { title: "Search Apps…", command: "omarchy-shell omarchy.dock apps" }
    ],
    view: [
      { title: "Change Wallpaper…", command: "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\"" },
      { title: "Next Wallpaper", command: "omarchy theme bg next" },
      { title: "Appearance…", command: "omarchy-shell brajam.golden-gate-menu show settings" },
      { title: "Menu", command: "omarchy menu toggle" }
    ],
    go: [
      { title: "Home", command: "uwsm-app -- nautilus ~" },
      { title: "Documents", command: "uwsm-app -- nautilus ~/Documents" },
      { title: "Downloads", command: "uwsm-app -- nautilus ~/Downloads" },
      { title: "Applications", command: "omarchy-shell omarchy.dock apps" }
    ],
    window: [
      { title: "Minimize", command: "bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/window-minimize.sh\"" },
      { title: "", command: "" },
      { title: "All Apps…", command: "omarchy-shell omarchy.dock apps" },
      { title: "Omarchy Menu…", command: "omarchy menu toggle" }
    ],
    help: [
      { title: "Omarchy Menu", command: "omarchy menu toggle" },
      { title: "Keyboard Shortcuts", command: "omarchy menu keybindings" },
      { title: "Theme Switcher", command: "omarchy-shell shell summon omarchy.image-picker '{\"source\":\"themes\"}'" }
    ]
  })

  function selectButton(id) {
    for (var i = 0; i < titles.length; i++) {
      if (titles[i].id === id) {
        selectedButton = headingRepeater.itemAt(i)
        return
      }
    }
  }
  function toggle(id) {
    if (id === "settings" || id === "dock") {
      popupOpen = false
      if (settingsWindow.opened && settingsWindow.page === (id === "dock" ? "dock" : "appearance")) settingsWindow.close()
      else settingsWindow.open(id === "dock" ? "dock" : "appearance")
      return
    }
    settingsWindow.close()
    selectButton(id)
    if (popupOpen && activeMenu === id) popupOpen = false
    else { activeMenu = id; popupOpen = true }
  }
  function run(command) {
    popupOpen = false
    if (command && root.bar) root.bar.run(command)
  }

  // The bar's stock active-panel underline spans the entire combined menu
  // widget. A separate coordinator lets macOS-like dropdowns open without
  // painting a long blue stripe under Finder…Help.
  QtObject {
    id: popupCoordinator
    function close() { root.popupOpen = false }
  }

  SettingsWindow {
    id: settingsWindow
    bar: root.bar
  }

  ShellIpc {
    target: "brajam.golden-gate-menu"
    function show(menu: string): void {
      if (menu === "desktop" || menu === "wallpaper" || menu === "displays") {
        root.popupOpen = false
        settingsWindow.open(menu)
        return
      }
      if (menu === "settings" || menu === "dock") {
        root.toggle(menu)
        return
      }
      if (Object.prototype.hasOwnProperty.call(root.entries, menu)) {
        root.selectButton(menu)
        root.activeMenu = menu
        root.popupOpen = true
      }
    }
    function hide(): void { root.close() }
  }

  implicitWidth: headings.implicitWidth + Style.space(6)
  implicitHeight: barSize

  Row {
    id: headings
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Repeater {
      id: headingRepeater
      model: root.titles
      delegate: Rectangle {
        id: menuButton
        required property var modelData
        width: heading.implicitWidth + (modelData.id === "apple" ? 23 : 15)
        height: root.barSize - 2
        radius: 6
        color: (root.popupOpen && root.activeMenu === modelData.id)
          || (settingsWindow.opened && (modelData.id === "dock" ? settingsWindow.page === "dock" : modelData.id === "settings" && settingsWindow.page !== "dock"))
          ? "#4c4644" : "transparent"

        Text {
          id: heading
          // Keep the Apple glyph measured and centered so toggling the peanut
          // does not move the rest of the menu bar.
          visible: !(menuButton.modelData.id === "apple" && root.peanutLogo)
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: menuButton.modelData.text
          color: root.bar ? root.bar.barForeground : "white"
          font.family: menuButton.modelData.id === "apple" ? "Font Awesome 7 Brands" : "Adwaita Sans"
          font.pixelSize: menuButton.modelData.id === "apple" ? 15 : 11
          font.weight: menuButton.modelData.id === "finder" ? Font.DemiBold : Font.Medium
        }
        Item {
          visible: menuButton.modelData.id === "apple" && root.peanutLogo
          anchors.centerIn: parent
          width: 13
          height: 13
          Image {
            id: peanutImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: Qt.resolvedUrl("peanut.svg")
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            // Hidden source texture for the bar-foreground mask below.
            visible: false
            layer.enabled: true
          }
          Rectangle {
            anchors.fill: peanutImage
            color: root.bar ? root.bar.barForeground : "white"
            layer.enabled: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: peanutImage
              maskThresholdMin: 0.5
              maskSpreadAtMin: 1.0
            }
          }
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggle(menuButton.modelData.id)
          onEntered: if (root.popupOpen && menuButton.modelData.id !== "settings" && menuButton.modelData.id !== "dock") {
            root.selectButton(menuButton.modelData.id)
            root.activeMenu = menuButton.modelData.id
          }
        }
      }
    }
  }

  MacPopupCard {
    id: popup
    anchorItem: root.selectedButton || root
    bar: root.bar
    owner: popupCoordinator
    open: root.popupOpen
    showOutline: !settingsWindow.dark || settingsWindow.dock.goldenGateDarkBorders === true
    margin: 2
    padding: 6
    contentWidth: popup.fittedContentWidth(Style.space(190))
    contentHeight: popup.fittedContentHeight(rows.implicitHeight)

    Column {
      id: rows
      anchors.fill: parent
      spacing: 1

      Repeater {
        model: root.entries[root.activeMenu] || []
        delegate: Item {
          id: menuRow
          required property var modelData
          width: rows.width
          height: modelData.title ? 29 : 12
          readonly property bool separator: !modelData.title

          Rectangle {
            visible: menuRow.separator
            x: 8
            y: 5
            width: parent.width - 16
            height: 1
            color: "#77717a"
            opacity: 0.25
          }
          Rectangle {
            visible: !menuRow.separator
            anchors.fill: parent
            radius: 6
            color: mouse.containsMouse ? "#267af5" : "transparent"
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: menuRow.modelData.title || ""
            color: mouse.containsMouse ? "white" : Commons.Color.popups.text
            font.family: "Adwaita Sans"
            font.pixelSize: 12
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: menuRow.modelData.shortcut || ""
            color: mouse.containsMouse ? "white" : "#85828a"
            font.family: "Adwaita Sans"
            font.pixelSize: 11
          }
          MouseArea {
            id: mouse
            visible: !menuRow.separator
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.run(menuRow.modelData.command)
          }
        }
      }
    }
  }
}
