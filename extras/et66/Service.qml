import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

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

    // ------------------------------------------------------- geometry
    // Design units (logical px); the shader works in device px.
    readonly property real dpr: win.screen ? win.screen.devicePixelRatio : 1
    readonly property rect bodyRect: Qt.rect(16, 12, 308, 516)
    readonly property rect displayRect: Qt.rect(38, 38, 264, 96)
    readonly property point gridOrigin: Qt.point(65, 190)
    readonly property real pitch: 70
    readonly property real keyR: 28
    property int pressedIdx: -1

    readonly property var keyModel: [
      "C", "±", "%", "÷",
      "7", "8", "9", "×",
      "4", "5", "6", "−",
      "1", "2", "3", "+",
      "0", ".", "⌫", "="
    ]

    // --------------------------------------------------------- printing
    // Labels (red) and display digits (green), drawn into a texture the
    // shader prints onto the keys and the LCD.
    Item {
      id: printLayer
      width: win.width; height: win.height
      visible: false

      Repeater {
        model: win.keyModel
        Text {
          required property int index
          required property var modelData
          x: win.gridOrigin.x + (index % 4) * win.pitch - width / 2
          y: win.gridOrigin.y + Math.floor(index / 4) * win.pitch - height / 2
          text: modelData
          color: "#ff0000"
          font.family: root.family
          font.weight: Font.Medium
          font.pixelSize: /^[0-9.]$/.test(modelData) ? 23 : 21
        }
      }
      Text {
        x: win.displayRect.x + win.displayRect.width - 16 - width
        y: win.displayRect.y + (win.displayRect.height - height) / 2 + 3
        text: root.display
        color: "#00ff00"
        font.family: root.monoFamily
        font.pixelSize: 46
        font.letterSpacing: 1
      }
      Text {
        x: win.displayRect.x + 14; y: win.displayRect.y + 12
        text: root.pending
        color: "#00ff00"
        font.family: root.family
        font.pixelSize: 15
      }
    }

    ShaderEffectSource {
      id: printSrc
      sourceItem: printLayer
      hideSource: true
      textureSize: Qt.size(printLayer.width * win.dpr, printLayer.height * win.dpr)
    }

    ShaderEffect {
      anchors.fill: parent
      fragmentShader: Qt.resolvedUrl("shaders/et66.frag.qsb")
      property size res: Qt.size(width * win.dpr, height * win.dpr)
      property rect body: Qt.rect(win.bodyRect.x * win.dpr, win.bodyRect.y * win.dpr,
                                  win.bodyRect.width * win.dpr, win.bodyRect.height * win.dpr)
      property real bodyRadius: 24 * win.dpr
      property rect display: Qt.rect(win.displayRect.x * win.dpr, win.displayRect.y * win.dpr,
                                     win.displayRect.width * win.dpr, win.displayRect.height * win.dpr)
      property point gridOrigin: Qt.point(win.gridOrigin.x * win.dpr, win.gridOrigin.y * win.dpr)
      property real keyPitch: win.pitch * win.dpr
      property real keyRadius: win.keyR * win.dpr
      property real pressed: win.pressedIdx
      property var printTex: printSrc
    }

    // --------------------------------------------------------- hit areas
    Repeater {
      model: win.keyModel
      Item {
        id: keyItem
        required property int index
        required property var modelData
        x: win.gridOrigin.x + (index % 4) * win.pitch - win.keyR
        y: win.gridOrigin.y + Math.floor(index / 4) * win.pitch - win.keyR
        width: win.keyR * 2; height: width

        Timer { id: flashTimer; interval: 110; onTriggered: if (win.pressedIdx === keyItem.index && !mouse.pressed) win.pressedIdx = -1 }
        Connections {
          target: root
          function onFlash(k) { if (k === keyItem.modelData) { win.pressedIdx = keyItem.index; flashTimer.restart() } }
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          onPressed: win.pressedIdx = keyItem.index
          onReleased: if (win.pressedIdx === keyItem.index) win.pressedIdx = -1
          onClicked: root.press(keyItem.modelData)
        }
      }
    }
  }
}
