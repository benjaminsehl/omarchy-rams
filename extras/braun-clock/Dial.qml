import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The Rams dial: a Braun wall clock (after Rams and Lubs) built like a
// watch. The whole surface is the dial. Hour indices are applied, the hands
// stand off the dial at three heights, and each throws a soft shadow away
// from a light at the top left. By day the lume channels are paper white;
// at night (dark: true) they glow.
//
// Used by the desktop wallpaper, the screensaver and the lock screen.
Item {
  id: dial

  // ----------------------------------------------------------- options
  property bool dark: false
  // "quartz": one damped step a second. "mechanical": 28,800 bph, eight
  // small steps a second. "smooth": continuous.
  property string movement: "quartz"
  // "classic" fills the height of the screen; "compact" sits in the middle.
  property string size: "classic"
  property bool running: true
  property bool showSeconds: true
  // Slow wander of a few pixels to spare OLED and plasma panels.
  property bool drift: false
  // Fixed time for stills (wallpaper PNGs). Null = now.
  property var fixedTime: null

  // ------------------------------------------------------------ palette
  readonly property color field: dark ? "#1b1a18" : "#efece6"
  readonly property color printInk: dark ? "#cfcac1" : "#2b2a27"
  readonly property color ink: dark ? "#5b5853" : "#2a2927"
  readonly property color inkEdge: dark ? "#2c2a27" : "#121110"
  readonly property color lume: dark ? "#eaf7d6" : "#f7f5f0"
  readonly property color glow: "#b6e48f"
  readonly property color signal_: dark ? "#f2b705" : "#e9a800"
  readonly property color shadowColor: dark ? "#000000" : "#3a3020"
  readonly property real shadowAlpha: dark ? 0.55 : 0.20
  readonly property string family: {
    var fams = Qt.fontFamilies()
    var prefs = ["ABC Areal", "Inter", "Helvetica Neue", "Noto Sans"]
    for (var i = 0; i < prefs.length; i++) if (fams.indexOf(prefs[i]) >= 0) return prefs[i]
    return "sans-serif"
  }

  // ----------------------------------------------------------- geometry
  readonly property real r: Math.min(width, height) * (size === "compact" ? 0.30 : 0.44)
  property real driftX: 0
  property real driftY: 0
  readonly property real cx: width / 2 + driftX
  readonly property real cy: height / 2 + driftY
  // Light from the top left: shadows fall down and to the right.
  readonly property real lightX: 0.45
  readonly property real lightY: 0.9

  // -------------------------------------------------------------- time
  property real secondAngle: 0
  property real minuteAngle: 0
  property real hourAngle: 0
  property bool settled: false

  function update() {
    var d = fixedTime ? fixedTime : new Date()
    var s = d.getSeconds() + d.getMilliseconds() / 1000
    if (movement === "quartz") s = Math.floor(s)
    else if (movement === "mechanical") s = Math.floor(s * 8) / 8
    var daySeconds = d.getHours() * 3600 + d.getMinutes() * 60 + s
    var next = daySeconds * 6
    // Midnight: the running total resets; don't animate a full turn back.
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
    interval: dial.movement === "smooth" ? 16 : (dial.movement === "mechanical" ? 125 : 100)
    running: dial.running && dial.visible && !dial.fixedTime
    repeat: true
    onTriggered: dial.update()
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

  // -------------------------------------------------------------- field
  Rectangle { anchors.fill: parent; color: dial.field }

  // Paper grain, barely there.
  Image {
    anchors.fill: parent
    source: Qt.resolvedUrl("grain.png")
    fillMode: Image.Tile
    opacity: dial.dark ? 0.035 : 0.04
    smooth: false
  }

  // A broad, soft fall of light from the top left.
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: dial.width * 0.25; centerY: dial.height * 0.1
        centerRadius: Math.max(dial.width, dial.height) * 0.9
        focalX: centerX; focalY: centerY
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, dial.dark ? 0.035 : 0.22) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, dial.dark ? 0.18 : 0.035) }
      }
      PathRectangle { x: 0; y: 0; width: dial.width; height: dial.height }
    }
  }

  // ---------------------------------------------- printed minute track
  Repeater {
    model: 60
    Item {
      required property int index
      readonly property bool five: index % 5 === 0
      x: dial.cx - width / 2; y: dial.cy - height / 2
      width: dial.r * 2; height: dial.r * 2
      rotation: index * 6
      Rectangle {
        x: dial.r - width / 2
        y: dial.r - dial.r * 0.985
        width: dial.r * (parent.five ? 0.0075 : 0.0055)
        height: dial.r * (parent.five ? 0.038 : 0.028)
        radius: width / 2
        color: dial.printInk
        opacity: parent.five ? 0.75 : 0.45
        antialiasing: true
      }
    }
  }

  // Minute figures outside the track, set along the circle.
  Repeater {
    model: 12
    Text {
      required property int index
      readonly property real deg: index * 30
      readonly property real a: deg * Math.PI / 180
      readonly property real rr: dial.r * 1.055
      text: index === 0 ? "60" : (index * 5 < 10 ? "0" + index * 5 : String(index * 5))
      color: dial.printInk
      opacity: 0.55
      font.family: dial.family
      font.pixelSize: Math.max(6, dial.r * 0.042)
      font.letterSpacing: dial.r * 0.002
      x: dial.cx + rr * Math.sin(a) - width / 2
      y: dial.cy - rr * Math.cos(a) - height / 2
      // Read from outside, and never upside down.
      rotation: deg > 90 && deg < 270 ? deg - 180 : deg
      renderType: Text.QtRendering
    }
  }

  // ---------------------------------------------------- applied indices
  component Index: Item {
    id: idx
    required property int index
    readonly property bool twelve: index === 0
    readonly property real len: dial.r * 0.135
    readonly property real wid: dial.r * (twelve ? 0.030 : 0.038)
    x: dial.cx - width / 2; y: dial.cy - height / 2
    width: dial.r * 2; height: dial.r * 2

    // Shadow, offset in screen space (so it is outside the rotation).
    Item {
      anchors.fill: parent
      anchors.leftMargin: dial.r * 0.006 * dial.lightX * 2
      anchors.topMargin: dial.r * 0.006 * dial.lightY * 2
      rotation: idx.index * 30
      Rectangle {
        id: idxShadowShape
        visible: false
        x: dial.r - width / 2; y: dial.r * (1 - 0.93)
        width: idx.wid; height: idx.len; radius: width / 2
        color: dial.shadowColor
      }
      MultiEffect {
        source: idxShadowShape
        anchors.fill: idxShadowShape
        blurEnabled: true; blur: 0.6; blurMax: 12
        opacity: dial.shadowAlpha
      }
    }

    Item {
      anchors.fill: parent
      rotation: idx.index * 30
      // Lume glow at night.
      Rectangle {
        id: idxGlowShape
        visible: false
        x: dial.r - width / 2; y: dial.r * (1 - 0.93) + idx.len * 0.12
        width: idx.wid * 0.5; height: idx.len * 0.76; radius: width / 2
        color: dial.glow
      }
      MultiEffect {
        visible: dial.dark
        source: idxGlowShape
        anchors.fill: idxGlowShape
        blurEnabled: true; blur: 1.0; blurMax: 24
        opacity: 0.8
      }
      // Body: a matte capsule with a lit upper edge.
      Rectangle {
        x: dial.r - width / 2; y: dial.r * (1 - 0.93)
        width: idx.wid; height: idx.len; radius: width / 2
        antialiasing: true
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.lighter(dial.ink, dial.dark ? 1.7 : 1.6) }
          GradientStop { position: 0.45; color: dial.ink }
          GradientStop { position: 1.0; color: dial.inkEdge }
        }
        // Lume fill.
        Rectangle {
          anchors.centerIn: parent
          width: parent.width * (dial.dark ? 0.46 : 0.30); height: parent.height - parent.width * 0.7
          radius: width / 2
          color: dial.lume
          opacity: dial.dark ? 1.0 : 0.85
          antialiasing: true
        }
      }
    }
  }
  Repeater { model: 12; delegate: Index {} }

  // Hour figures, inside the indices.
  Repeater {
    model: 12
    Text {
      required property int index
      readonly property real a: (index + 1) * Math.PI / 6
      readonly property real rr: dial.r * 0.66
      text: index + 1
      color: dial.printInk
      font.family: dial.family
      font.weight: Font.Medium
      font.pixelSize: Math.max(8, dial.r * 0.115)
      x: dial.cx + rr * Math.sin(a) - width / 2
      y: dial.cy - rr * Math.cos(a) - height / 2
      renderType: Text.QtRendering
    }
  }

  // --------------------------------------------------------------- hands
  // A baton hand standing `lift` above the dial: its shadow falls further
  // the higher it stands, and is softer.
  component Hand: Item {
    id: hand
    property real angle
    property real length
    property real tail
    property real thickness
    property real lift: 1
    property bool lumed: true
    property color body: dial.ink
    property int stepDuration: 0
    x: dial.cx - width / 2; y: dial.cy - height / 2
    width: dial.r * 2; height: dial.r * 2

    property real shown: angle
    Behavior on shown {
      enabled: hand.stepDuration > 0 && dial.settled
      NumberAnimation { duration: hand.stepDuration; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }

    Item {
      anchors.fill: parent
      anchors.leftMargin: dial.r * 0.011 * hand.lift * dial.lightX * 2
      anchors.topMargin: dial.r * 0.011 * hand.lift * dial.lightY * 2
      rotation: hand.shown
      Rectangle {
        id: handShadowShape
        visible: false
        x: dial.r - width / 2; y: dial.r - dial.r * hand.length
        width: dial.r * hand.thickness; height: dial.r * (hand.length + hand.tail)
        radius: width * 0.18
        color: dial.shadowColor
      }
      MultiEffect {
        source: handShadowShape
        anchors.fill: handShadowShape
        blurEnabled: true; blur: Math.min(1, 0.45 + hand.lift * 0.18); blurMax: 20
        opacity: dial.shadowAlpha * (1.05 - hand.lift * 0.12)
      }
    }

    Item {
      anchors.fill: parent
      rotation: hand.shown
      Rectangle {
        id: handGlowShape
        visible: false
        x: dial.r - width / 2; y: dial.r - dial.r * (hand.length - 0.05)
        width: dial.r * hand.thickness * 0.45; height: dial.r * (hand.length - 0.17)
        radius: width / 2
        color: dial.glow
      }
      MultiEffect {
        visible: dial.dark && hand.lumed
        source: handGlowShape
        anchors.fill: handGlowShape
        blurEnabled: true; blur: 1.0; blurMax: 28
        opacity: 0.85
      }
      Rectangle {
        x: dial.r - width / 2; y: dial.r - dial.r * hand.length
        width: dial.r * hand.thickness; height: dial.r * (hand.length + hand.tail)
        radius: width * 0.18
        antialiasing: true
        // A shallow ridge down the hand, lit from the left.
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.lighter(hand.body, dial.dark ? 1.7 : 1.7) }
          GradientStop { position: 0.5; color: hand.body }
          GradientStop { position: 1.0; color: Qt.darker(hand.body, 1.25) }
        }
        Rectangle {
          visible: hand.lumed
          x: (parent.width - width) / 2; y: dial.r * 0.05
          width: parent.width * 0.42; height: dial.r * (hand.length - 0.17)
          radius: width / 2
          color: dial.lume
          antialiasing: true
        }
      }
    }
  }

  // Hub under the hands.
  Item {
    x: dial.cx - width / 2 + dial.r * 0.006; y: dial.cy - height / 2 + dial.r * 0.012
    width: dial.r * 0.11; height: width
    Rectangle { id: hubShadowShape; visible: false; anchors.fill: parent; radius: width / 2; color: dial.shadowColor }
    MultiEffect { source: hubShadowShape; anchors.fill: parent; blurEnabled: true; blur: 0.6; blurMax: 12; opacity: dial.shadowAlpha }
  }

  Hand { angle: dial.hourAngle; length: 0.50; tail: 0.10; thickness: 0.060; lift: 1.0 }
  Hand { angle: dial.minuteAngle; length: 0.82; tail: 0.10; thickness: 0.043; lift: 1.6 }

  Rectangle {
    x: dial.cx - width / 2; y: dial.cy - height / 2
    width: dial.r * 0.085; height: width; radius: width / 2
    antialiasing: true
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.lighter(dial.ink, dial.dark ? 1.8 : 1.8) }
      GradientStop { position: 1.0; color: Qt.darker(dial.ink, 1.2) }
    }
  }

  // Second hand: Braun yellow, thin, standing highest.
  Hand {
    visible: dial.showSeconds
    angle: dial.secondAngle
    length: 0.90; tail: 0.24; thickness: 0.011; lift: 2.4
    lumed: false
    body: dial.signal_
    stepDuration: dial.movement === "quartz" ? 170 : 0
  }

  Rectangle {
    visible: dial.showSeconds
    x: dial.cx - width / 2; y: dial.cy - height / 2
    width: dial.r * 0.05; height: width; radius: width / 2
    color: dial.signal_
    antialiasing: true
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.32; height: width; radius: width / 2
      color: Qt.darker(dial.signal_, 1.5)
      antialiasing: true
    }
  }
}
