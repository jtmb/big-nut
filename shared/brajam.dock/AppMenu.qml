import QtQuick

// The menu capability supplies the dock's app grid with the same scoped
// application library Omarchy's own menu uses. The service owns the UI.
Item {
  property var shell: null
  property var manifest: null

  function open() {
    var dock = shell ? shell.serviceFor("brajam.dock") : null
    if (dock) dock.openApps()
  }

  function close() { }
}
