import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Windows 10 taskbar controls: Start, search, Task View and app buttons.
// The tray and clock live in brajam.windows-clock at the opposite end.
BarWidget {
  id: root
  moduleName: "brajam.windows-taskbar"

  property var shellConfig: ({})
  property string searchQuery: ""
  property bool startOpen: false
  property bool taskViewOpen: false
  property bool jumpOpen: false
  property var jumpItem: null
  property Item jumpAnchor: null
  property var itemAnchors: ({})
  readonly property var taskbarConfig: shellConfig.windowsTaskbar || ({})
  readonly property var pinnedIds: taskbarConfig.pinned !== undefined
    ? taskbarConfig.pinned
    : ["org.gnome.Nautilus", "chromium", "foot", "libreoffice-writer"]

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.shellConfig = JSON.parse(text()) } catch (e) { root.shellConfig = ({}) } }
    onFileChanged: reload()
  }

  function entryForAppId(appId) {
    var id = String(appId || "")
    if (!id) return null
    var entry = DesktopEntries.heuristicLookup(id)
    if (entry) return entry
    var entries = DesktopEntries.applications.values
    var flag = "--app-id=" + id
    for (var i = 0; i < entries.length; i++)
      if (String(entries[i].execString || "").indexOf(flag) >= 0) return entries[i]
    return null
  }

  function iconFor(item) {
    if (item && item.key === "org.omarchy.agent")
      return "file:///usr/share/omarchy/shell/plugins/agents/assets/opencode.svg"
    var icon = item && item.entry && item.entry.icon ? item.entry.icon : "application-x-executable"
    return Quickshell.iconPath(icon, true)
  }

  // Pinned apps first in their saved order, then running windows that are not
  // pinned. A pinned app without a window is shown without a running underline.
  readonly property var items: {
    var result = []
    var byKey = ({})
    var pinned = root.pinnedIds || []
    for (var i = 0; i < pinned.length; i++) {
      var entry = DesktopEntries.byId(pinned[i])
      if (!entry || entry.noDisplay) continue
      var item = { key: entry.id, name: entry.name, entry: entry, windows: [] }
      result.push(item)
      byKey[entry.id] = item
    }
    var toplevels = Hyprland.toplevels.values
    for (var j = 0; j < toplevels.length; j++) {
      var toplevel = toplevels[j]
      var wayland = toplevel.wayland
      if (!wayland || !wayland.appId || wayland.parent) continue
      var appEntry = root.entryForAppId(wayland.appId)
      var key = appEntry ? appEntry.id : wayland.appId
      if (!byKey[key]) {
        var added = { key: key, name: appEntry ? appEntry.name : (key === "org.omarchy.agent" ? "OpenCode" : wayland.appId), entry: appEntry || null, windows: [] }
        result.push(added)
        byKey[key] = added
      }
      var workspace = toplevel.workspace
      byKey[key].windows.push({
        address: toplevel.address,
        toplevel: toplevel,
        activated: wayland.activated === true,
        minimized: !!workspace && String(workspace.name || "") === "special:minimized"
      })
    }
    for (var k = 0; k < result.length; k++) {
      var entryItem = result[k]
      entryItem.running = entryItem.windows.length > 0
      entryItem.active = entryItem.windows.some(function(window) { return window.activated })
    }
    return result
  }

  function launch(entry) {
    if (!entry) return
    if (root.bar && root.bar.shell && root.bar.shell.appLibrary)
      root.bar.shell.appLibrary.launch(entry.id, entry.name)
    else
      root.bar.run("gtk-launch " + Util.shellQuote(entry.id))
  }

  function focusWindow(window) {
    if (!window) return
    if (!window.minimized) {
      window.toplevel.activate()
      return
    }
    var address = String(window.address || "")
    if (!address) return
    if (address.indexOf("0x") !== 0) address = "0x" + address
    var target = "window = \"address:" + address + "\""
    var workspace = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
      ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.move({ workspace = \"" + workspace + "\", " + target + " })"))
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ " + target + " })"))
  }

  function activate(item) {
    if (!item) return
    root.startOpen = false
    if (!item.running) { root.launch(item.entry); return }
    if (item.active) {
      for (var i = 0; i < item.windows.length; i++) {
        var address = String(item.windows[i].address || "")
        if (address) root.bar.run("bash \"$HOME/.config/omarchy/themes/windows-10/window-minimize.sh\" " + Util.shellQuote(address))
      }
      return
    }
    var window = item.windows[0]
    for (var j = 0; j < item.windows.length; j++)
      if (!item.windows[j].minimized) { window = item.windows[j]; break }
    root.focusWindow(window)
  }

  function openStart() {
    root.startOpen = true
    startView.open(startButton, "", false)
  }
  function closeStart() { root.startOpen = false; startView.close() }
  function toggleStart() {
    if (root.startOpen) root.closeStart()
    else { root.taskViewOpen = false; taskView.close(); root.openStart() }
  }
  function openSearch(text) {
    root.taskViewOpen = false
    taskView.close()
    root.startOpen = true
    startView.open(searchBox, text, true)
  }
  function openJump(anchor, item) {
    root.closeStart()
    root.jumpAnchor = anchor
    root.jumpItem = item
    root.jumpOpen = true
  }
  function closeJump() { root.jumpOpen = false }
  function togglePin(item) {
    if (!item) return
    var pinned = root.pinnedIds.indexOf(item.key) >= 0
    root.bar.run("bash \"$HOME/.config/omarchy/themes/windows-10/taskbar-pin.sh\" "
      + (pinned ? "unpin " : "pin ") + Util.shellQuote(item.key))
    root.closeJump()
  }
  function closeAllWindows(item) {
    if (!item) return
    for (var i = 0; i < item.windows.length; i++) {
      var address = String(item.windows[i].address || "")
      if (!address) continue
      if (address.indexOf("0x") !== 0) address = "0x" + address
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.window.close({ window = \"address:" + address + "\" })"))
    }
    root.closeJump()
  }
  function openJumpItem(item) {
    if (!item) return
    if (item.running) { root.focusWindow(item.windows[0]) } else { root.launch(item.entry) }
    root.closeJump()
  }
  function toggleTaskView() {
    root.closeStart()
    root.taskViewOpen = !root.taskViewOpen
    if (root.taskViewOpen) { taskView.open(taskViewButton) } else { taskView.close() }
  }

  implicitWidth: 48 + 4 + 240 + 6 + 40 + root.items.length * 40
  implicitHeight: root.barSize

  Item { id: jumpProxy; visible: false; width: 40; height: root.barSize; y: 0 }

  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Item {
      id: startButton
      width: 48
      height: root.barSize
      Rectangle {
        anchors.fill: parent
        color: startMouse.containsMouse || root.startOpen ? "#26ffffff" : "transparent"
      }
      // Windows 10 start mark: four white panes.
      Grid {
        anchors.centerIn: parent
        columns: 2
        columnSpacing: 2
        rowSpacing: 2
        Repeater {
          model: 4
          delegate: Rectangle { required property int index; width: 8; height: 8; color: "#ffffff" }
        }
      }
      MouseArea {
        id: startMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleStart()
      }
    }

    Item { width: 4; height: 1 }

    Item {
      id: searchBox
      width: 240
      height: root.barSize
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 30
        color: searchMouse.containsMouse ? "#2b2b2b" : "#1f1f1f"
        border.width: 1
        border.color: searchField.activeFocus ? "#0078d7" : "#4a4a4a"
      }
      Text {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        text: "\uf002"
        font.family: "Font Awesome 7 Free Solid"
        font.pixelSize: 13
        color: "#ffffff"
      }
      TextInput {
        id: searchField
        x: 32; width: parent.width - 40
        anchors.verticalCenter: parent.verticalCenter
        color: "#ffffff"
        selectionColor: "#0078d7"
        selectedTextColor: "#ffffff"
        font.family: "Selawik"
        font.pixelSize: 13
        clip: true
        text: root.searchQuery
        onTextEdited: { root.searchQuery = text; root.openSearch(text) }
        Keys.onEscapePressed: { text = ""; root.searchQuery = ""; root.closeStart(); searchField.focus = false }
        Text {
          visible: !parent.text.length
          anchors.verticalCenter: parent.verticalCenter
          text: "Search the web and Windows"
          color: "#b8b8b8"
          font: parent.font
        }
      }
      MouseArea {
        id: searchMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: searchField.forceActiveFocus()
      }
    }

    Item { width: 6; height: 1 }

    Item {
      id: taskViewButton
      width: 40
      height: root.barSize
      Rectangle {
        anchors.fill: parent
        color: taskViewMouse.containsMouse || root.taskViewOpen ? "#26ffffff" : "transparent"
      }
      Item {
        anchors.centerIn: parent
        width: 18; height: 14
        Rectangle { x: 0; y: 0; width: 13; height: 10; color: "transparent"; border.width: 1; border.color: "#ffffff" }
        Rectangle { x: 5; y: 4; width: 13; height: 10; color: "#ffffff" }
      }
      MouseArea {
        id: taskViewMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleTaskView()
      }
    }

    Repeater {
      model: root.items
      delegate: Item {
        id: appButton
        required property var modelData
        width: 40
        height: root.barSize
        Component.onCompleted: root.itemAnchors[modelData.key] = appButton
        Rectangle {
          anchors.fill: parent
          color: appMouse.containsMouse ? "#26ffffff" : "transparent"
        }
        Image {
          anchors.centerIn: parent
          width: 24; height: 24
          source: root.iconFor(modelData)
          fillMode: Image.PreserveAspectFit
          sourceSize.width: 48
          sourceSize.height: 48
        }
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: 16; height: 2
          color: modelData.active ? "#0078d7" : modelData.running ? "#9a9a9a" : "transparent"
        }
        MouseArea {
          id: appMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: function(event) {
            if (event.button === Qt.RightButton) root.openJump(parent, modelData)
            else root.activate(modelData)
          }
        }
      }
    }
  }

  PopupWindow {
    id: jumpMenu
    anchor {
      id: jumpAnchorPoint
      window: root.jumpAnchor ? root.jumpAnchor.QsWindow.window : null
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1
      onAnchoring: {
        if (!root.jumpAnchor || !root.bar) return
        var win = root.jumpAnchor.QsWindow.window
        if (!win) return
        var point = win.contentItem.mapFromItem(root.jumpAnchor, root.jumpAnchor.width - jumpMenu.implicitWidth, -jumpMenu.implicitHeight)
        jumpAnchorPoint.rect.x = Math.round(Math.max(8, Math.min(point.x, win.width - jumpMenu.implicitWidth - 8)))
        jumpAnchorPoint.rect.y = Math.round(Math.max(8, point.y))
      }
    }
    visible: root.jumpOpen
    color: "transparent"
    implicitWidth: 240
    implicitHeight: root.jumpItem && root.jumpItem.running ? 150 : 118
    mask: Region { item: root.jumpOpen ? jumpPanel : null }

    HyprlandFocusGrab {
      active: root.jumpOpen
      windows: root.jumpAnchor && root.jumpAnchor.QsWindow.window
        ? [jumpMenu, root.jumpAnchor.QsWindow.window] : [jumpMenu]
      onCleared: root.closeJump()
    }

    Rectangle {
      id: jumpPanel
      anchors.fill: parent
      color: "#2b2b2b"
      border.width: 1; border.color: "#4d4d4d"

      Item {
        width: parent.width; height: 34
        Image {
          x: 10; anchors.verticalCenter: parent.verticalCenter
          width: 18; height: 18
          source: root.jumpItem ? root.iconFor(root.jumpItem) : ""
          fillMode: Image.PreserveAspectFit
        }
        Text {
          x: 36; anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 46
          text: root.jumpItem ? root.jumpItem.name : ""
          color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12; font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
      }
      Rectangle { y: 34; width: parent.width; height: 1; color: "#4d4d4d" }

      Column {
        y: 38
        width: parent.width
        spacing: 1
        Repeater {
          model: [
            { label: "Open", action: "open" },
            { label: root.jumpItem && root.pinnedIds.indexOf(root.jumpItem.key) >= 0 ? "Unpin from taskbar" : "Pin to taskbar", action: "pin" },
            { label: "Close all windows", action: "close", runningOnly: true }
          ]
          delegate: Rectangle {
            required property var modelData
            width: parent.width; height: 32
            visible: !modelData.runningOnly || (root.jumpItem && root.jumpItem.running)
            color: jumpMouse.containsMouse ? "#3f3f3f" : "transparent"
            Text {
              x: 10; anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: "#ffffff"; font.family: "Selawik"; font.pixelSize: 12
            }
            MouseArea {
              id: jumpMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.action === "open") root.openJumpItem(root.jumpItem)
                else if (modelData.action === "pin") root.togglePin(root.jumpItem)
                else root.closeAllWindows(root.jumpItem)
              }
            }
          }
        }
      }
    }
  }

  StartMenu {
    id: startView
    bar: root.bar
    query: root.searchQuery
    onDismissed: root.startOpen = false
    onLaunchRequested: function(entry) { root.launch(entry); root.closeStart() }
    onSettingsRequested: { root.closeStart(); settingsView.open("appearance") }
  }

  TaskView {
    id: taskView
    bar: root.bar
    onDismissed: root.taskViewOpen = false
  }

  WindowsSettings {
    id: settingsView
    bar: root.bar
  }

  ShellIpc {
    target: "brajam.windows-taskbar"
    function start(): void { root.toggleStart() }
    function search(text: string): void { root.openSearch(String(text || "")) }
    function taskview(): void { root.toggleTaskView() }
    function settings(page: string): void { root.closeStart(); settingsView.open(page || "appearance") }
    function closesettings(): void { settingsView.close() }
    function closejump(): void { root.closeJump() }
    function jump(key: string): void {
      for (var i = 0; i < root.items.length; i++)
        if (root.items[i].key === key) {
          jumpProxy.x = 48 + 4 + 240 + 6 + 40 + i * 40
          root.openJump(jumpProxy, root.items[i])
          return
        }
    }
    function hide(): void { root.closeStart(); taskView.close() }
    function debugItems(): string {
      return JSON.stringify(root.items.map(function(item) {
        return { key: item.key, name: item.name, running: item.running, active: item.active, count: item.windows.length }
      }))
    }
  }
}
