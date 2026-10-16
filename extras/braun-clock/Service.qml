import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// The Rams clock, in three places:
//
//   Desktop      With a Rams theme and the 0-clock wallpaper, the whole
//                desktop is a live dial (layer: bottom, under every window).
//   Screensaver  While Omarchy's screensaver runs on a Rams theme, the dial
//                covers it (layer: overlay). Input passes straight through
//                to the screensaver, so dismissing and locking behave exactly
//                as stock. The dial drifts slowly against burn-in.
//   Lock screen  The Rams lock view loads Dial.qml from this folder.
//
// Options, all optional, in ~/.config/omarchy-rams/clock.json:
//   { "movement": "quartz", "screensaverMovement": "mechanical",
//     "size": "classic", "screensaver": true, "seconds": true }
// movement: quartz | mechanical | smooth.   size: classic | compact.
//
// Try the screensaver dial: omarchy-shell braunClock preview
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/omarchy/current"
  property string themeName: ""
  property string backgroundPath: ""
  property var config: ({})
  readonly property bool ramsTheme: /^rams(-|$)/.test(themeName)
  readonly property bool dark: themeName === "rams-dark"
  readonly property bool desktopActive: ramsTheme && /\/0-clock\.png$/.test(backgroundPath)

  property var screensavers: ({})
  property int screensaverCount: 0
  property bool previewing: false
  readonly property bool screensaverActive: (ramsTheme && config.screensaver !== false && screensaverCount > 0) || previewing

  function opt(key, fallback) {
    var v = config[key]
    return (v === undefined || v === null || v === "") ? fallback : v
  }

  FileView {
    path: root.stateDir + "/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: { root.themeName = String(text() || "").trim(); root.checkBackground() }
    onFileChanged: reload()
  }

  FileView {
    path: root.home + "/.config/omarchy-rams/clock.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.config = JSON.parse(text()) || {} } catch (e) { root.config = {} } }
    onLoadFailed: root.config = {}
    onFileChanged: reload()
  }

  function checkBackground() {
    if (!readlink.running) readlink.running = true
  }

  // `omarchy theme bg` repoints a symlink without telling anyone, so look
  // again every few seconds, on Rams themes only.
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

  // Follow Omarchy's screensaver windows the same way its idle service does.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event && event.name ? event.name : "")
      var parts = String(event && event.data ? event.data : "").split(",")
      var next = Object.assign({}, root.screensavers)
      if (name === "openwindow" && parts[2] === "org.omarchy.screensaver") next[parts[0]] = true
      else if (name === "closewindow" && next[parts[0]]) delete next[parts[0]]
      else return
      root.screensavers = next
      root.screensaverCount = Object.keys(next).length
    }
  }

  IpcHandler {
    target: "braunClock"
    // Shows the screensaver dial until a click, or for 30 seconds.
    function preview(): string { root.previewing = true; previewTimer.restart(); return "ok" }
    function hide(): string { root.previewing = false; return "ok" }
    function status(): string {
      return JSON.stringify({ theme: root.themeName, desktop: root.desktopActive,
        screensaver: root.screensaverActive, background: root.backgroundPath, config: root.config })
    }
  }
  Timer { id: previewTimer; interval: 30000; onTriggered: root.previewing = false }

  Process {
    id: bgSwitch
    command: ["bash", "-c", "b=$(omarchy-theme-bg-switcher); [[ -n $b ]] && omarchy-theme-bg-set \"$b\""]
  }
  Process {
    id: themeSwitch
    command: ["bash", "-c", "t=$(omarchy-theme-switcher); [[ -n $t ]] && omarchy-theme-set \"$t\" >/dev/null 2>&1 &"]
  }

  // ------------------------------------------------------------ desktop
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.desktopActive
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "sehl-braun-clock"
      // Bottom: above omarchy.background, below every window.
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Dial {
        anchors.fill: parent
        dark: root.dark
        running: root.desktopActive && !root.screensaverActive
        movement: root.opt("movement", "quartz")
        size: root.opt("size", "classic")
        showSeconds: root.opt("seconds", true)
      }

      // The stock wallpaper's gestures: double-click for a wallpaper,
      // right double-click for a theme.
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

  // --------------------------------------------------------- screensaver
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: saver
      required property var modelData
      screen: modelData
      visible: root.screensaverActive || fade.running
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "sehl-braun-clock-screensaver"
      WlrLayershell.layer: WlrLayer.Overlay
      // Never take the keyboard: the stock screensaver must see the key that
      // dismisses it, and a preview must not swallow typing. A preview takes
      // clicks only.
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: root.previewing ? catcher : null }

      Item {
        id: face
        anchors.fill: parent
        opacity: root.screensaverActive ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: 600; easing.type: Easing.InOutSine } }

        Dial {
          anchors.fill: parent
          dark: root.dark || root.opt("screensaverDark", true)
          running: saver.visible
          movement: root.opt("screensaverMovement", "mechanical")
          size: root.opt("size", "classic")
          showSeconds: root.opt("seconds", true)
          drift: true
        }
      }

      MouseArea {
        id: catcher
        anchors.fill: parent
        enabled: root.previewing
        onClicked: root.previewing = false
      }
    }
  }
}
