#!/usr/bin/env python3
"""Give a clone of omarchy.lock the Rams lock screen.

On Rams themes the blurred wallpaper is replaced by the live dial
(sehl.braun-clock's Dial.qml) and the password field becomes a slim slot
below the hub. Every other theme sees the stock lock screen, and the
authentication code (Service.qml, PAM) is not touched.

Usage: patch-lockview.py ~/.config/omarchy/plugins/<you>.lock/LockView.qml

Each edit anchors on text from the stock LockView. If Omarchy changes that
text, the script stops without writing anything, so the clone stays stock.
"""
import pathlib
import sys

MARK = "// rams-lock:"


def main(path):
    p = pathlib.Path(path)
    s = p.read_text()
    if MARK in s:
        print(f"{p}: already patched")
        return 0

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
         '  readonly property string placeholderText: ramsDial ? "Password" : "Enter Password"\n'
         '  readonly property int fieldWidth: ramsDial ? 280 : 381\n'
         '  readonly property int fieldHeight: ramsDial ? 46 : 67\n'),

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
        ("      radius: Style.cornerRadius\n      clip: true\n",
         "      radius: root.ramsDial ? height / 2 : Style.cornerRadius\n      clip: true\n"),
    ]

    for old, new in edits:
        if s.count(old) != 1:
            print(f"{p}: stock text not found, leaving the clone unpatched:\n{old}", file=sys.stderr)
            return 1
        s = s.replace(old, new)

    # The outline is 3px on stock; a hairline suits the slot.
    s = s.replace("  readonly property int outlineThickness: 3\n",
                  "  readonly property int outlineThickness: ramsDial ? 1 : 3\n")
    p.write_text(s)
    print(f"{p}: patched")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]) if len(sys.argv) == 2 else 2)
