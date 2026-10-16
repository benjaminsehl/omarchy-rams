// Renders the clock wallpapers from extras/braun-clock/Dial.qml, so the
// still and the live clock are the same drawing.
//   RAMS_REPO=$PWD qs -p tools/render-dial   (writes backgrounds/0-clock.png for both variants)
// The window sits on the background layer, under the wallpaper, so nothing
// shows while it renders.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
  id: root
  // Set by the caller: RAMS_REPO=$PWD qs -p tools/render-dial
  readonly property string repo: Quickshell.env("RAMS_REPO") + "/"
  property var jobs: [
    { dark: false, out: repo + "backgrounds/0-clock.png" },
    { dark: true, out: repo + "variants/dark/backgrounds/0-clock.png" }
  ]
  property int job: 0

  PanelWindow {
    implicitWidth: 64; implicitHeight: 64
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "rams-render"

    Loader {
      id: still
      width: 1920; height: 1200
      source: "file://" + root.repo + "extras/braun-clock/Dial.qml"
      onLoaded: {
        item.anchors.fill = still
        item.running = false
        item.fixedTime = new Date(2026, 0, 1, 10, 8, 37)
        item.dark = Qt.binding(function() { return root.jobs[root.job].dark })
      }
    }

    Timer {
      interval: 1500; running: true; repeat: false
      onTriggered: root.grab()
    }
  }

  function grab() {
    var j = jobs[job]
    still.grabToImage(function(result) {
      result.saveToFile(j.out)
      console.log("wrote", j.out)
      if (job + 1 < jobs.length) { job += 1; again.start() } else Qt.quit()
    }, Qt.size(1920, 1200))  // doubled by the 2x output: 3840x2400
  }
  Timer { id: again; interval: 1200; onTriggered: root.grab() }
}
