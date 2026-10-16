import QtQuick

// A Braun wall clock face. Geometry is in units of the face radius and
// mirrors CLOCK in tools/wallpapers.py; keep the two in step.
Item {
  id: clock

  property bool running: true
  property color face: "#f7f5f0"
  property color rim: "#d3cec4"
  property color ink: "#2b2a27"
  property color signal_: "#e9a800"

  readonly property real r: width / 2

  // The second hand's angle accumulates instead of wrapping at 360, so its
  // animated step from 59 to 0 still turns clockwise. The other hands move
  // without animation, so they can simply wrap.
  property real secondAngle: 0
  property real minuteAngle: 0
  property real hourAngle: 0
  property int lastSecond: -1
  property int turns: 0
  property bool started: false

  function tick() {
    var d = new Date()
    var s = d.getSeconds()
    if (s === lastSecond) return
    if (lastSecond >= 0 && s < lastSecond) turns += 1
    lastSecond = s
    var m = d.getMinutes() + s / 60
    secondAngle = (turns * 60 + s) * 6
    minuteAngle = m * 6
    hourAngle = ((d.getHours() % 12) + m / 60) * 30
    started = true
  }

  Timer {
    // Poll faster than once a second so the step lands on the boundary.
    interval: 100
    running: clock.running && clock.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: clock.tick()
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: clock.face
    border.color: clock.rim
    border.width: Math.max(1, clock.r * 0.012)
    antialiasing: true
  }

  Repeater {
    model: 60
    Item {
      required property int index
      readonly property bool hour: index % 5 === 0
      readonly property real inner: hour ? 0.855 : 0.915
      readonly property real outer: 0.965
      readonly property real w: hour ? 0.026 : 0.010
      anchors.fill: parent
      rotation: index * 6
      Rectangle {
        x: clock.r - width / 2
        y: clock.r - clock.r * parent.outer
        width: clock.r * parent.w
        height: clock.r * (parent.outer - parent.inner)
        color: clock.ink
        antialiasing: true
      }
    }
  }

  Repeater {
    model: 12
    Text {
      required property int index
      readonly property real a: (index + 1) * Math.PI / 6
      text: index + 1
      color: clock.ink
      font.family: "ABC Areal"
      font.weight: Font.Medium
      font.pixelSize: clock.r * 0.135
      x: clock.r + clock.r * 0.725 * Math.sin(a) - width / 2
      y: clock.r - clock.r * 0.725 * Math.cos(a) - height / 2
      renderType: Text.QtRendering
    }
  }

  component Hand: Item {
    id: hand
    property real length
    property real tail
    property real thickness
    property color color
    property real angle
    property int stepDuration: 0
    anchors.fill: parent
    rotation: angle
    Behavior on rotation {
      enabled: hand.stepDuration > 0 && clock.started
      NumberAnimation { duration: hand.stepDuration; easing.type: Easing.OutCubic }
    }
    Rectangle {
      x: clock.r - width / 2
      y: clock.r - clock.r * hand.length
      width: clock.r * hand.thickness
      height: clock.r * (hand.length + hand.tail)
      color: hand.color
      antialiasing: true
    }
  }

  Hand { length: 0.50; tail: 0.10; thickness: 0.052; color: clock.ink; angle: clock.hourAngle }
  Hand { length: 0.80; tail: 0.10; thickness: 0.036; color: clock.ink; angle: clock.minuteAngle }
  // Quartz step: a short, damped move once a second.
  Hand { length: 0.86; tail: 0.24; thickness: 0.014; color: clock.signal_; angle: clock.secondAngle; stepDuration: 140 }

  Rectangle {
    width: clock.r * 0.10
    height: width
    radius: width / 2
    anchors.centerIn: parent
    color: clock.signal_
    antialiasing: true
  }
}
