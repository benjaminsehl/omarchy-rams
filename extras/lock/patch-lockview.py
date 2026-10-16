#!/usr/bin/env python3
"""Give a clone of omarchy.lock the Rams lock screen.

On Rams themes the blurred wallpaper is replaced by the live dial
(sehl.braun-clock's Dial.qml) and the password field becomes a slim slot
below the hub. Every other theme sees the stock lock screen, and the
authentication code (Service.qml, PAM) is not touched.

Usage: patch-lockview.py ~/.config/omarchy/plugins/<you>.lock/LockView.qml

Each edit anchors on text from the stock LockView. If Omarchy changes that
text, the script stops without writing anything, so the clone stays stock.

The unpatched view is kept as LockView.qml.orig next to it, so re-running
after an update to this script re-patches from the original.
"""
import pathlib
import sys

MARK = "// rams-lock:"
STOCK = pathlib.Path("/usr/share/omarchy/shell/plugins/lock")


def main(path):
    p = pathlib.Path(path)
    orig = p.with_name(p.name + ".orig")
    s = p.read_text()
    if MARK in s:
        if not orig.exists():
            # Patched before .orig existed: the stock view is the original
            # only if the clone's Service.qml is still the stock one.
            if (p.parent / "Service.qml").read_text() != (STOCK / "Service.qml").read_text():
                print(f"{p}: patched by an older version and no original kept; re-clone omarchy.lock", file=sys.stderr)
                return 1
            orig.write_text((STOCK / "LockView.qml").read_text())
        s = orig.read_text()
    else:
        orig.write_text(s)

    edits = [
        # Imports for the theme-name watcher.
        ("import QtQuick.Effects\n",
         "import QtQuick.Effects\nimport Quickshell\nimport Quickshell.Io\n"),

        # Theme detection + slimmer field on Rams.
        ('  readonly property string placeholderText: "Enter Password"\n'
         '  readonly property int fieldWidth: 381\n'
         '  readonly property int fieldHeight: 67\n',
         f'  {MARK} the live Rams dial replaces the wallpaper on Rams themes.\n'
         '  property string themeName: ""\n'
         '  readonly property bool ramsDial: dialLoader.status === Loader.Ready\n'
         '  FileView {\n'
         '    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"\n'
         '    watchChanges: true\n'
         '    printErrors: false\n'
         '    onLoaded: root.themeName = String(text() || "").trim()\n'
         '    onFileChanged: reload()\n'
         '  }\n\n'
         '  // Rams: no box. A hairline rule on the dial, a small printed label,\n'
         '  // dots in lume at night and ink by day, a shake for a wrong password.\n'
         '  readonly property color ramsInk: themeName === "rams-dark" ? "#b2f0a4" : "#3a3631"\n'
         '  readonly property color ramsLabel: themeName === "rams-dark" ? Qt.rgba(0.70, 0.94, 0.64, 0.55) : Qt.rgba(0.23, 0.21, 0.19, 0.60)\n'
         '  readonly property color ramsRule: themeName === "rams-dark" ? Qt.rgba(0.70, 0.94, 0.64, 0.28) : Qt.rgba(0.23, 0.21, 0.19, 0.30)\n'
         '  readonly property string ramsFamily: Qt.fontFamilies().indexOf("ABC Areal") >= 0 ? "ABC Areal" : Style.font.family\n'
         '  onFailureMessageChanged: if (ramsDial && failureMessage.length > 0) ramsShake.restart()\n'
         '  SequentialAnimation {\n'
         '    id: ramsShake\n'
         '    NumberAnimation { target: ramsShakeT; property: "x"; to: -9; duration: 45; easing.type: Easing.OutQuad }\n'
         '    NumberAnimation { target: ramsShakeT; property: "x"; to: 7; duration: 70; easing.type: Easing.InOutQuad }\n'
         '    NumberAnimation { target: ramsShakeT; property: "x"; to: -4; duration: 70; easing.type: Easing.InOutQuad }\n'
         '    NumberAnimation { target: ramsShakeT; property: "x"; to: 0; duration: 90; easing.type: Easing.OutQuad }\n'
         '  }\n\n'
         '  readonly property string placeholderText: ramsDial ? "password" : "Enter Password"\n'
         '  readonly property int fieldWidth: ramsDial ? 260 : 381\n'
         '  readonly property int fieldHeight: ramsDial ? 44 : 67\n'),

        # Field text scale follows the slimmer field.
        ("  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)\n",
         "  readonly property int fieldFontSize: ramsDial ? Style.font.subtitle : Math.round(Style.font.heading * 1.125)\n"),

        # Skip the wallpaper and blur when the dial is up.
        ("      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : \"\"\n",
         "      source: root.loadBackground && !root.ramsDial ? root.fileUrl(root.backgroundPath) : \"\"\n"),

        # The dial itself, above the (now empty) wallpaper.
        ("    MouseArea {\n      anchors.fill: parent\n      hoverEnabled: true\n",
         "    Loader {\n"
         "      id: dialLoader\n"
         "      anchors.fill: parent\n"
         "      active: /^rams(-|$)/.test(root.themeName)\n"
         "      source: active ? \"file://\" + Quickshell.env(\"HOME\") + \"/.config/omarchy/plugins/sehl.braun-clock/Dial.qml\" : \"\"\n"
         "      onLoaded: {\n"
         "        item.dark = Qt.binding(function() { return root.themeName === \"rams-dark\" })\n"
         "        item.running = Qt.binding(function() { return root.visible })\n"
         "      }\n"
         "    }\n\n"
         "    MouseArea {\n      anchors.fill: parent\n      hoverEnabled: true\n"),

        # Field: centred normally, a slot below the hub on Rams.
        ("      height: root.fieldHeight\n      anchors.centerIn: parent\n",
         "      height: root.fieldHeight\n"
         "      anchors.horizontalCenter: parent.horizontalCenter\n"
         "      anchors.verticalCenter: parent.verticalCenter\n"
         "      anchors.verticalCenterOffset: root.ramsDial ? Math.min(parent.width, parent.height) * 0.44 * 0.36 : 0\n"),

        # A full pill on Rams, like a Braun slider slot.
        ("      color: Color.lock.background\n      borderSpec: root.inputBorderSpec\n      radius: Style.cornerRadius\n      clip: true\n",
         "      color: root.ramsDial ? \"transparent\" : Color.lock.background\n"
         "      borderSpec: root.inputBorderSpec\n"
         "      radius: Style.cornerRadius\n"
         "      clip: !root.ramsDial\n"
         "      transform: Translate { id: ramsShakeT }\n"),

        # Dots: a small bullet, spaced; lume or ink; no caret; dim while checking.
        ('        passwordCharacter: "\\u25CF"\n',
         '        passwordCharacter: root.ramsDial ? "\\u2022" : "\\u25CF"\n'
         '        opacity: root.ramsDial && root.authenticatingPassword ? 0.4 : 1.0\n'
         '        Behavior on opacity { NumberAnimation { duration: 200 } }\n'),
        ("        color: Color.lock.text\n        selectionColor:",
         "        color: root.ramsDial ? root.ramsInk : Color.lock.text\n        selectionColor:"),
        ("        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize\n"
         "        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0\n"
         "        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0\n",
         "        font.pixelSize: root.ramsDial ? 22 : (text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize)\n"
         "        font.letterSpacing: root.ramsDial ? 6 : (text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0)\n"
         "        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0 && !root.ramsDial\n"),

        # Label colour: a printed tone of the dial, not grey.
        ("        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)\n",
         "        color: root.authenticatingPassword ? (root.ramsDial ? root.ramsInk : Color.lock.text) : (root.failureMessage.length > 0 ? Color.lock.textError : (root.ramsDial ? root.ramsLabel : Color.lock.placeholder))\n"),

        # Label: small, spaced, printed.
        ("        font.family: Style.font.family\n        font.pixelSize: root.fieldFontSize\n        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0\n",
         "        font.family: root.ramsDial ? root.ramsFamily : Style.font.family\n"
         "        font.pixelSize: root.fieldFontSize\n"
         "        font.letterSpacing: root.ramsDial ? 1.8 : 0\n"
         "        font.italic: !root.ramsDial && !root.authenticatingPassword && root.failureMessage.length > 0\n"),

        # The hairline rule, after the fingerprint icon block's anchor text.
        ("      // Fingerprint hint pinned inside the field's right edge when a sensor is\n",
         "      Rectangle {\n"
         "        visible: root.ramsDial\n"
         "        anchors.horizontalCenter: parent.horizontalCenter\n"
         "        anchors.bottom: parent.bottom\n"
         "        width: 170\n"
         "        height: 1\n"
         "        color: root.errorState ? Color.lock.textError : (passwordInput.text.length > 0 ? Color.accent : root.ramsRule)\n"
         "        Behavior on color { ColorAnimation { duration: 180 } }\n"
         "      }\n\n"
         "      // Fingerprint hint pinned inside the field's right edge when a sensor is\n"),
    ]

    for old, new in edits:
        if s.count(old) != 1:
            print(f"{p}: stock text not found, leaving the clone unpatched:\n{old}", file=sys.stderr)
            return 1
        s = s.replace(old, new)

    # The outline is 3px on stock; a hairline suits the slot.
    s = s.replace("  readonly property int outlineThickness: 3\n",
                  "  readonly property int outlineThickness: ramsDial ? 0 : 3\n")
    p.write_text(s)
    print(f"{p}: patched")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]) if len(sys.argv) == 2 else 2)
