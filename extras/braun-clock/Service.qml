import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Live hands for the Rams theme's 0-clock wallpaper.
//
// The wallpaper PNG already holds the full clock, stopped at 10:08. This
// plugin maps a small, centred, clock-sized layer above it and draws the same
// face with moving hands, so nothing else about the desktop changes. It only
// appears while a Rams theme is active and the clock wallpaper is selected.
// Every other theme and wallpaper sees no surface at all.
Item {
  id: root

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/current"
  property string themeName: ""
  property string backgroundPath: ""
  readonly property bool ramsTheme: /^rams(-|$)/.test(themeName)
  readonly property bool dark: themeName === "rams-dark"
  readonly property bool active: ramsTheme && /\/0-clock\.png$/.test(backgroundPath)

  FileView {
    path: root.stateDir + "/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: { root.themeName = String(text() || "").trim(); root.checkBackground() }
    onFileChanged: reload()
  }

  function checkBackground() {
    if (!readlink.running) readlink.running = true
  }

  // The background is a symlink that `omarchy theme bg` repoints; there is no
  // change signal for it, so look again every few seconds on Rams themes only.
  Process {
    id: readlink
    command: ["readlink", "-f", root.stateDir + "/background"]
    stdout: StdioCollector { onStreamFinished: root.backgroundPath = String(text || "").trim() }
  }
  Timer {
    interval: 2000
    running: root.ramsTheme
    repeat: true
    onTriggered: root.checkBackground()
  }

  Process {
    id: bgSwitch
    command: ["bash", "-c", "b=$(omarchy-theme-bg-switcher); [[ -n $b ]] && omarchy-theme-bg-set \"$b\""]
  }
  Process {
    id: themeSwitch
    command: ["bash", "-c", "t=$(omarchy-theme-switcher); [[ -n $t ]] && omarchy-theme-set \"$t\" >/dev/null 2>&1 &"]
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.active

      // No anchors: layer-shell centres the surface, exactly where the
      // wallpaper (cropped to fill, centred) puts its clock. Wallpaper is
      // 3840x2400 with the face at 0.56 of its height.
      readonly property real cover: Math.max(modelData.width / 3840, modelData.height / 2400)
      readonly property real faceSize: Math.round(2400 * 0.56 * cover)
      implicitWidth: faceSize + 4
      implicitHeight: faceSize + 4

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "sehl-braun-clock"
      // Bottom: above omarchy.background, below every window.
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Clock {
        anchors.centerIn: parent
        width: panel.faceSize
        height: panel.faceSize
        running: root.active
        face: root.dark ? "#121110" : "#f7f5f0"
        rim: root.dark ? "#34322e" : "#d3cec4"
        ink: root.dark ? "#dedad2" : "#2b2a27"
        signal_: root.dark ? "#f2b705" : "#e9a800"
      }

      // Same gestures as the stock wallpaper: double-click to pick a
      // wallpaper, right double-click to pick a theme.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) { if (!themeSwitch.running) themeSwitch.running = true }
          else if (!bgSwitch.running) bgSwitch.running = true
        }
      }
    }
  }
}
