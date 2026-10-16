import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

// A pocket calculator after the Braun ET 66 (Rams and Lubs, 1987): a dark
// body, a recessed display, round convex keys in a strict grid, an orange
// clear key and the yellow equals key.
//
//   omarchy-shell et66 toggle     (Rams themes bind SUPER+CTRL+Q to this)
//
// Keyboard: digits, . , + - * / % Enter/= Backspace, Delete/c clears,
// n negates, Escape closes. Ctrl+C copies the display.
Item {
  id: root

  property bool open: false

  // ------------------------------------------------------------ engine
  // Immediate execution, like the real thing: 2 + 3 × 4 = 20.
  property string display: "0"
  property real acc: 0
  property string pending: ""
  property bool fresh: true       // next digit starts a new entry
  property bool error: false
  property string lastOp: ""      // for repeated =
  property real lastOperand: 0

  readonly property int maxDigits: 10

  function fmt(v) {
    if (!isFinite(v)) { error = true; return "E" }
    var s = Number(v.toPrecision(maxDigits)).toString()
    if (s.indexOf("e") >= 0 || s.replace(/[-.]/g, "").length > maxDigits) {
      var a = Math.abs(v)
      if (a >= Math.pow(10, maxDigits)) { error = true; return "E" }
      s = Number(v.toFixed(Math.max(0, maxDigits - 1 - Math.floor(Math.log10(Math.max(a, 1)))))).toString()
    }
    return s
  }

  function value() { return Number(display) }

  function apply(a, op, b) {
    switch (op) {
      case "+": return a + b
      case "−": return a - b
      case "×": return a * b
      case "÷": return b === 0 ? NaN : a / b
    }
    return b
  }

  function press(k) {
    if (error && k !== "C") return
    if (/^[0-9]$/.test(k)) {
      if (fresh) { display = k; fresh = false }
      else if (display.replace(/[-.]/g, "").length < maxDigits) display = display === "0" ? k : display + k
    } else if (k === ".") {
      if (fresh) { display = "0."; fresh = false }
      else if (display.indexOf(".") < 0) display += "."
    } else if (k === "C") {
      display = "0"; acc = 0; pending = ""; fresh = true; error = false; lastOp = ""
    } else if (k === "⌫") {
      if (!fresh) display = display.length > 1 && display !== "-0" ? display.slice(0, -1).replace(/^-$/, "0") : "0"
    } else if (k === "±") {
      display = display.charAt(0) === "-" ? display.slice(1) : (display === "0" ? "0" : "-" + display)
    } else if (k === "%") {
      var pct = pending ? acc * value() / 100 : value() / 100
      display = fmt(pct); fresh = true
    } else if (k === "=") {
      if (pending) {
        lastOp = pending; lastOperand = value()
        display = fmt(apply(acc, pending, lastOperand)); pending = ""
      } else if (lastOp) {
        display = fmt(apply(value(), lastOp, lastOperand))
      }
      fresh = true
    } else {
      // + − × ÷
      if (pending && !fresh) display = fmt(apply(acc, pending, value()))
      acc = value(); pending = k; fresh = true; lastOp = ""
    }
    flash(k)
  }

  signal flash(string k)

  function toggle() { open = !open }

  IpcHandler {
    target: "et66"
    function toggle(): string { root.toggle(); return root.open ? "open" : "closed" }
    function show(): string { root.open = true; return "open" }
    function hide(): string { root.open = false; return "closed" }
    function press(key: string): string { root.press(key); return root.display }
  }

  Process {
    id: copy
    property string text: ""
    command: ["wl-copy", text]
  }

  // ------------------------------------------------------------- object
  readonly property string family: {
    var fams = Qt.fontFamilies()
    var prefs = ["ABC Areal", "Inter", "Noto Sans"]
    for (var i = 0; i < prefs.length; i++) if (fams.indexOf(prefs[i]) >= 0) return prefs[i]
    return "sans-serif"
  }
  readonly property string monoFamily: Qt.fontFamilies().indexOf("ABC Areal Mono") >= 0 ? "ABC Areal Mono" : "monospace"

  PanelWindow {
    id: win
    visible: root.open
    color: "transparent"
    implicitWidth: 340
    implicitHeight: 560
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "sehl-et66"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      id: keys
      anchors.fill: parent
      focus: root.open
      Keys.onPressed: function(e) {
        var t = e.text
        if (e.key === Qt.Key_Escape) root.open = false
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) { copy.text = root.display; copy.running = true }
        else if (/^[0-9.]$/.test(t)) root.press(t)
        else if (t === ",") root.press(".")
        else if (t === "+") root.press("+")
        else if (t === "-") root.press("−")
        else if (t === "*" || t === "x") root.press("×")
        else if (t === "/") root.press("÷")
        else if (t === "%") root.press("%")
        else if (t === "n") root.press("±")
        else if (t === "=" || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.press("=")
        else if (e.key === Qt.Key_Backspace) root.press("⌫")
        else if (e.key === Qt.Key_Delete || t === "c") root.press("C")
        else return
        e.accepted = true
      }
    }

    // Shadow under the body.
    Rectangle {
      id: bodyShadow
      visible: false
      x: body.x + 6; y: body.y + 14
      width: body.width; height: body.height; radius: body.radius
      color: "#000000"
    }
    MultiEffect {
      source: bodyShadow
      anchors.fill: bodyShadow
      blurEnabled: true; blur: 1.0; blurMax: 32
      opacity: 0.45
    }

    Rectangle {
      id: body
      x: 16; y: 12
      width: parent.width - 32; height: parent.height - 40
      radius: 22
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#34302b" }
        GradientStop { position: 1.0; color: "#26231f" }
      }
      border.color: "#403b35"
      border.width: 1

      // Display window, recessed.
      Rectangle {
        id: well
        x: 22; y: 26
        width: parent.width - 44; height: 96
        radius: 10
        color: "#1a1816"
        Rectangle {
          anchors.fill: parent
          anchors.margins: 5
          radius: 7
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#a9ac98" }
            GradientStop { position: 1.0; color: "#bfc2ad" }
          }
          // Inner shadow at the top edge of the glass.
          Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 10; radius: 7
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }
          Text {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
            text: root.display
            color: "#23251e"
            font.family: root.monoFamily
            font.pixelSize: 46
            font.letterSpacing: 1
          }
          Text {
            anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 8 }
            text: root.pending
            color: "#3a3d33"
            font.family: root.family
            font.pixelSize: 16
          }
        }
      }

      // The key grid: 4 columns, 5 rows, round keys.
      Grid {
        id: grid
        x: 26; y: well.y + well.height + 30
        columns: 4
        spacing: 14
        readonly property real key: (body.width - 52 - 3 * 14) / 4

        Repeater {
          model: [
            { k: "C", kind: "clear" }, { k: "±", kind: "fn" }, { k: "%", kind: "fn" }, { k: "÷", kind: "op" },
            { k: "7" }, { k: "8" }, { k: "9" }, { k: "×", kind: "op" },
            { k: "4" }, { k: "5" }, { k: "6" }, { k: "−", kind: "op" },
            { k: "1" }, { k: "2" }, { k: "3" }, { k: "+", kind: "op" },
            { k: "0" }, { k: "." }, { k: "⌫", kind: "fn" }, { k: "=", kind: "equals" }
          ]

          Item {
            id: keyItem
            required property var modelData
            readonly property string kind: modelData.kind || "digit"
            readonly property color cap: kind === "clear" ? "#e2552a"
              : kind === "equals" ? "#f2b705"
              : kind === "op" ? "#5b4d40"
              : kind === "fn" ? "#4a443d" : "#3c3833"
            readonly property color label: kind === "equals" ? "#2a2520" : "#efebe3"
            property bool down: mouse.pressed || flashTimer.running
            width: grid.key; height: grid.key

            Timer { id: flashTimer; interval: 110 }
            Connections {
              target: root
              function onFlash(k) { if (k === keyItem.modelData.k) flashTimer.restart() }
            }

            // Shadow
            Rectangle {
              id: capShadow
              visible: false
              anchors.fill: parent
              radius: width / 2
              color: "#000000"
            }
            MultiEffect {
              source: capShadow
              anchors.fill: capShadow
              anchors.topMargin: keyItem.down ? 1 : 4
              anchors.leftMargin: keyItem.down ? 0 : 2
              blurEnabled: true; blur: 0.7; blurMax: 12
              opacity: 0.55
            }

            // The cap: convex, lit from above.
            Rectangle {
              anchors.fill: parent
              anchors.margins: keyItem.down ? 2 : 0
              radius: width / 2
              color: keyItem.cap
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(keyItem.cap, keyItem.down ? 1.05 : 1.28) }
                GradientStop { position: 0.55; color: keyItem.cap }
                GradientStop { position: 1.0; color: Qt.darker(keyItem.cap, 1.25) }
              }
              // A dished centre, as on the ET 66 keys.
              Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.72; height: width; radius: width / 2
                gradient: Gradient {
                  GradientStop { position: 0.0; color: Qt.darker(keyItem.cap, 1.12) }
                  GradientStop { position: 1.0; color: Qt.lighter(keyItem.cap, 1.08) }
                }
              }
              Text {
                anchors.centerIn: parent
                text: keyItem.modelData.k
                color: keyItem.label
                font.family: root.family
                font.weight: Font.Medium
                font.pixelSize: keyItem.kind === "digit" ? 24 : 22
              }
            }

            MouseArea {
              id: mouse
              anchors.fill: parent
              onClicked: root.press(keyItem.modelData.k)
            }
          }
        }
      }

      Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        text: "Rams"
        color: "#6f675d"
        font.family: root.family
        font.pixelSize: 11
        font.letterSpacing: 2
      }
    }
  }
}
