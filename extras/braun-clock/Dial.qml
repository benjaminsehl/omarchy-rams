import QtQuick
import QtQuick.Window

// The Rams dial: a Braun wall clock (after Rams and Lubs) rendered as an
// object under one light. See shaders/dial.frag for the drawing; this file
// sets the time, the palette and the printing.
//
// Used by the desktop wallpaper, the screensaver and the lock screen.
Item {
  id: dial

  // ----------------------------------------------------------- options
  property bool dark: false
  // "quartz": a stepper tick once a second (snap, overshoot, settle).
  // "mechanical": 28,800 beats an hour, eight beats a second, as on a
  //   Rolex or Grand Seiko; each beat is a jump, so eight frames a second.
  // "smooth": continuous glide, redrawn every frame.
  property string movement: "quartz"
  property string size: "classic"   // classic | compact
  property bool running: true
  property bool showSeconds: true
  property bool drift: false        // slow wander against burn-in
  property var fixedTime: null      // Date for stills; null = now
  // The dial's field. Unset, it's the dial's own tone (noir at night); the
  // desktop passes the theme background, so popovers and the dial are one
  // material.
  property color fieldColor: "transparent"

  // ------------------------------------------------------------ palette
  // Ink is a deep tone of the dial, not black, so it reads as printed.
  readonly property color dialColor: fieldColor.a > 0 ? fieldColor : (dark ? "#0e0e0d" : "#efece6")
  readonly property color inkColor: dark ? "#3a3833" : "#3a3631"
  readonly property color lumeDay: "#f6f3ec"
  readonly property color lumeNight: "#b2f0a4"
  readonly property color handTint: dark ? "#1c1b1a" : "#1f1e1c"
  readonly property color paintColor: dark ? "#f2b705" : "#e9a800"

  // ----------------------------------------------------------- geometry
  readonly property real r: Math.min(width, height) * (size === "compact" ? 0.30 : 0.42)
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  property real driftX: 0
  property real driftY: 0
  readonly property real printScale: 1.02

  // -------------------------------------------------------------- time
  property real secondAngle: 0   // degrees, accumulating (see below)
  property real minuteAngle: 0
  property real hourAngle: 0
  property real secondShown: secondAngle
  property bool settled: false

  function update() {
    var d = fixedTime ? fixedTime : new Date()
    var s = d.getSeconds() + d.getMilliseconds() / 1000
    if (movement === "quartz") s = Math.floor(s)
    else if (movement === "mechanical") s = Math.floor(s * 8) / 8
    var day = d.getHours() * 3600 + d.getMinutes() * 60 + s
    // The second hand's angle accumulates through the day, so its animated
    // quartz step from 59 to 0 still turns forward.
    var next = day * 6
    if (next < secondAngle) settled = false
    secondAngle = next
    minuteAngle = (d.getMinutes() + s / 60) * 6
    hourAngle = ((d.getHours() % 12) + d.getMinutes() / 60 + s / 3600) * 30
    Qt.callLater(function() { dial.settled = true })
  }

  Component.onCompleted: update()
  onFixedTimeChanged: update()
  onMovementChanged: update()

  Timer {
    interval: dial.movement === "mechanical" ? 125 : 100
    running: dial.running && dial.visible && !dial.fixedTime && dial.movement !== "smooth"
    repeat: true
    onTriggered: dial.update()
  }
  FrameAnimation {
    running: dial.running && dial.visible && !dial.fixedTime && dial.movement === "smooth"
    onTriggered: dial.update()
  }

  // Quartz: the stepper snaps forward, overshoots a hair and settles.
  Behavior on secondShown {
    enabled: dial.movement === "quartz" && dial.settled
    NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
  }

  NumberAnimation on driftX {
    running: dial.drift && dial.running
    from: -dial.width * 0.012; to: dial.width * 0.012
    duration: 97000; loops: Animation.Infinite; easing.type: Easing.InOutSine
  }
  NumberAnimation on driftY {
    running: dial.drift && dial.running
    from: -dial.height * 0.012; to: dial.height * 0.012
    duration: 131000; loops: Animation.Infinite; easing.type: Easing.InOutSine
  }

  // ------------------------------------------------------------ printing
  // Drawn once into a texture the shader treats as ink on the dial. No
  // figures: the applied indices and a fine minute track say enough.
  Item {
    id: printLayer
    width: dial.r * dial.printScale * 2
    height: width
    visible: false
    readonly property real r: dial.r
    readonly property real c: width / 2

    // Minute track: fine dashes between the applied indices.
    Repeater {
      model: 60
      Item {
        required property int index
        visible: index % 5 !== 0
        anchors.fill: parent
        rotation: index * 6
        Rectangle {
          x: printLayer.c - width / 2
          y: printLayer.c - printLayer.r * 0.965
          width: Math.max(1, printLayer.r * 0.0058)
          height: printLayer.r * 0.055
          radius: width / 2
          color: "#ff0000"
          antialiasing: true
        }
      }
    }

  }

  ShaderEffectSource {
    id: printSrc
    sourceItem: printLayer
    hideSource: true
    live: true
    smooth: true
    textureSize: Qt.size(printLayer.width * dial.dpr, printLayer.height * dial.dpr)
  }

  // --------------------------------------------------------------- object
  ShaderEffect {
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("shaders/dial.frag.qsb")

    property size res: Qt.size(width * dial.dpr, height * dial.dpr)
    property point center: Qt.point((width / 2 + dial.driftX) * dial.dpr, (height / 2 + dial.driftY) * dial.dpr)
    property real radius: dial.r * dial.dpr
    property real hourA: dial.hourAngle * Math.PI / 180
    property real minA: dial.minuteAngle * Math.PI / 180
    property real secA: dial.secondShown * Math.PI / 180
    property real night: dial.dark ? 1.0 : 0.0
    property real showSec: dial.showSeconds ? 1.0 : 0.0
    property real printScale: dial.printScale
    property color dialColor: dial.dialColor
    property color inkColor: dial.inkColor
    property color lumeDay: dial.lumeDay
    property color lumeNight: dial.lumeNight
    property color handTint: dial.handTint
    property color paintColor: dial.paintColor
    property var printTex: printSrc
  }
}
