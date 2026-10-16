# Rams — an Omarchy theme

After Dieter Rams' work for Braun. *Weniger, aber besser.*

![Rams](preview.png)

Rams treats the desktop like a Braun object: a neutral body, honest
materials, type that is easy to read, and one point of colour that means
something.

| | Rams | Rams Dark |
|---|---|---|
| After | SK 4, the white Braun clocks | ET 66, T 1000, the black AB 1 |
| Body | warm enamel white `#eeebe5` | charcoal `#1d1c1a` |
| Edge | charcoal `#3a3935` | aluminium `#b9b4aa` |
| Signal | Braun orange `#d4521c` | Braun orange `#f0692b` |
| Second hand | Braun yellow `#e9a800` | Braun yellow `#f2b705` |

## Principles, as applied

- **Colour is a signal.** Structure is grey. Orange marks the one thing that
  is focused, selected or active: the selected menu row, keyboard focus,
  the lock field while you type, the notification countdown, recording
  indicators. Red means an error and nothing else. Syntax colouring in pi is
  mostly ink: keywords are darker, only strings and numbers get colour.
- **Honest surfaces.** Windows, menus, popups and the lock field are fully
  opaque. No blur, shadows or gradients. Edges are 1px hairlines, or the 2px
  window border.
- **One radius.** 6px everywhere (Hyprland rounding, which the shell
  mirrors), like the corners of an SK 4 or an ET 66 key.
- **Calm motion.** One ease-out curve, short durations, no overshoot, no
  slide-ins.
- **Type does the work.** ABC Areal Mono for terminals, bar and menus, ABC
  Areal for GTK apps and window group tabs. A short type scale, a slightly
  looser spacing grid, and tooltips inverted like the labels on a Braun
  control.
- **Useful, not decorative.** The default wallpaper is a Braun wall clock
  (after Rams and Dietrich Lubs) that keeps real time.

## What's in it

| File | What it does |
|---|---|
| `colors.toml` | Palette. Terminals, Neovim, VS Code, Chromium, Obsidian, keyboard RGB etc. are generated from it |
| `hyprland.lua` | Borders, radius, opacity, no blur/shadow, motion, group tabs |
| `shell.toml` | Every Omarchy shell surface: bar, controls, menus, launcher, notifications, tooltips, lock, polkit, picker |
| `pi.json` | Quiet palette for the pi coding agent |
| `btop.theme` | Meters read like a level indicator: grey, then ink, then orange at the top |
| `backgrounds/` | Clock, SK 4 grille, T 3 perforation, ET 66 keys, the motto set in Areal |
| `extras/braun-clock/` | `sehl.braun-clock` shell plugin: live hands for the clock wallpaper |
| `hooks/rams-typography.sh` | theme-set hook: Areal on Rams, your previous fonts back on other themes |
| `tools/build.py` | Regenerates `hyprland.lua`, `shell.toml`, `pi.json`, `btop.theme` for both variants from `colors.toml` |
| `tools/wallpapers.py` | Regenerates the wallpapers (needs `rsvg-convert` and Areal) |

The dark variant lives in `variants/dark/` and has the same files.

## Install

1. Fonts. ABC Areal is a commercial Dinamo typeface and is **not** in this
   repo. Install your licensed copy:

   ```bash
   mkdir -p ~/.local/share/fonts/ABCAreal
   cp ~/Downloads/ABCAreal/ABC\ Areal*/TTF/*.ttf ~/.local/share/fonts/ABCAreal/
   fc-cache -f
   ```

2. Theme, clock plugin and typography hook:

   ```bash
   git clone https://github.com/benjaminsehl/omarchy-rams.git ~/.local/share/omarchy-rams
   ~/.local/share/omarchy-rams/install.sh
   omarchy theme set rams        # or rams-dark
   ```

`install.sh` links the themes to the clone instead of using
`omarchy theme install`. Omarchy drops `hyprland.lua` from themes installed
that way, and the clock plugin and the hook would be left out. If you do
use `omarchy theme install`, you get the palette, shell, wallpapers and
borders, but not the motion, opacity or radius.

## The clock

`0-clock.png` is the clock stopped at 10:08. With a Rams theme and that
wallpaper both active, `sehl.braun-clock` maps a clock-sized layer over it
and draws the same face with moving hands. The second hand steps once a
second, like a quartz movement. For any other wallpaper or theme, the plugin
maps nothing. The lock screen and the wallpaper picker see the static image.

Pick another wallpaper with `omarchy theme bg next` or by double-clicking the
desktop.

The geometry lives in two places that must agree: `CLOCK` in
`tools/wallpapers.py` and `extras/braun-clock/Clock.qml`.

## Typography hook

Omarchy's font is system-wide, not part of a theme. The hook makes it follow
the theme:

- Switching to `rams*` saves your fonts (to
  `~/.local/state/rams-theme/fonts.prev`) and sets Areal. In Omarchy that
  means `omarchy font set` for terminals, bar and menus. In GTK it means
  `font-name`, `document-font-name` and `monospace-font-name`.
- Switching to anything else restores the saved fonts.

`omarchy hook install` copies the script, so re-run `./install.sh` after
editing it.

## Uninstall

```bash
rm ~/.config/omarchy/themes/rams ~/.config/omarchy/themes/rams-dark
omarchy plugin disable sehl.braun-clock && rm ~/.config/omarchy/plugins/sehl.braun-clock
rm ~/.config/omarchy/hooks/theme-set.d/rams-typography.sh
```

Switch to another theme first, so the hook restores your fonts.
