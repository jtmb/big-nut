import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons

Item {
  id: root
  property var shell: null
  property var manifest: null
  property date now: new Date()
  property string location: "Weather"
  property string temperature: "—"
  property string detail: "Current conditions"
  property var config: ({})
  readonly property bool darkAppearance: Commons.Color.background.r + Commons.Color.background.g + Commons.Color.background.b < 1.5
  // This is the same dark-only preference used by the dock and menu surfaces.
  readonly property bool darkBorders: (config.dock || {}).goldenGateDarkBorders === true

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.config = JSON.parse(text()) } catch (e) { root.config = ({}) } }
    onFileChanged: reload()
  }

  Timer { interval: 60000; repeat: true; running: true; onTriggered: root.now = new Date() }
  Timer {
    interval: 900000
    repeat: true
    triggeredOnStart: true
    running: true
    onTriggered: if (!weather.running) weather.running = true
  }
  // The user's existing Omarchy weather command uses their configured
  // location. Only its short, bounded output is displayed as plain text.
  Process {
    id: weather
    command: ["omarchy", "weather", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var report = String(text || "").slice(0, 180).replace(/[\r\n]+/g, " ")
        var match = report.match(/^(.{1,50}?)\s+·\s+Temp\s+([+-]?\d+°[CF])(?:\s+·\s+(.{1,60}))?/)
        if (match) {
          root.location = match[1]
          root.temperature = match[2]
          root.detail = match[3] || "Current conditions"
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: desktop
        required property var modelData
        screen: modelData
        color: "transparent"
        WlrLayershell.namespace: "golden-gate-desktop-widgets"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        implicitWidth: 247
        implicitHeight: 267
        // Only the three cards receive input; the rest of the desktop remains
        // click-through, and normal application windows stay above this layer.
        mask: Region {
          item: calendar
          Region { item: weatherCard }
          Region { item: pictureCard }
        }

        Item {
          x: 10
          y: 40
          width: 227
          height: 217

          Rectangle {
            id: calendar
            width: 108
            height: 108
            radius: 13
            color: root.darkAppearance ? "#292d41" : "#f7f7f7"
            border.color: root.darkAppearance ? "#7782a2" : "#ffffff"
            border.width: root.darkAppearance && !root.darkBorders ? 0 : 1

            Column {
              x: 9
              y: 6
              spacing: 4
              Text {
                textFormat: Text.PlainText
                text: Qt.formatDate(root.now, "MMMM").toUpperCase()
                color: root.darkAppearance ? "#ff8d93" : "#d5524a"
                font.family: "Adwaita Sans"
                font.weight: Font.DemiBold
                font.pixelSize: 7
              }
              Row {
                Repeater {
                  model: ["S", "M", "T", "W", "T", "F", "S"]
                  delegate: Text {
                    required property var modelData
                    width: 12.9
                    textFormat: Text.PlainText
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: root.darkAppearance ? "#b7bed3" : "#8f8e94"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 6
                  }
                }
              }
              Grid {
                columns: 7
                rowSpacing: 3
                Repeater {
                  model: 42
                  delegate: Item {
                    required property int index
                    width: 12.9
                    height: 10
                    readonly property int first: new Date(root.now.getFullYear(), root.now.getMonth(), 1).getDay()
                    readonly property int count: new Date(root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate()
                    readonly property int dateNumber: index - first + 1
                    readonly property bool inMonth: dateNumber > 0 && dateNumber <= count
                    Rectangle {
                      visible: parent.inMonth && parent.dateNumber === root.now.getDate()
                      anchors.centerIn: parent
                      width: 10; height: 10; radius: 5
                      color: "#d9514d"
                    }
                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: parent.inMonth ? String(parent.dateNumber) : ""
                      color: parent.dateNumber === root.now.getDate() ? "white" : (root.darkAppearance ? "#f0eff8" : "#424046")
                      font.family: "Adwaita Sans"
                      font.pixelSize: 7
                    }
                  }
                }
              }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              // Omarchy's calendar stays anchored to its existing bar widget.
              onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.clock"])
            }
          }

          Rectangle {
            id: weatherCard
            x: 118
            width: 108
            height: 108
            radius: 13
            gradient: Gradient {
              GradientStop { position: 0; color: root.darkAppearance ? "#244478" : "#70b9f3" }
              GradientStop { position: 1; color: root.darkAppearance ? "#252538" : "#347bd1" }
            }
            Text {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: 9
              width: parent.width - 18
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: root.location
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.pixelSize: 10
            }
            Text {
              x: 9; y: 27
              textFormat: Text.PlainText
              text: root.temperature
              color: "#ffffff"
              font.family: "Adwaita Sans"
              font.weight: Font.Light
              font.pixelSize: 34
            }
            Text {
              x: 9; y: 85
              width: parent.width - 18
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: root.detail
              color: "#e4e9f7"
              font.family: "Adwaita Sans"
              font.pixelSize: 8
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              // The theme preset mounts this widget so its forecast panel exists.
              onClicked: Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.weather"])
            }
          }

          Rectangle {
            id: pictureCard
            y: 117
            width: 226
            height: 99
            radius: 13
            clip: true
            color: "transparent"
            Image {
              anchors.fill: parent
              source: Qt.resolvedUrl("purple-card.webp")
              fillMode: Image.PreserveAspectCrop
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              // The artwork is a shortcut to Wallpaper, not a photo library.
              onClicked: Quickshell.execDetached(["omarchy-shell", "brajam.golden-gate-menu", "show", "wallpaper"])
            }
          }
        }
      }
    }
  }
}
