#!/bin/bash
# theme-set hook: Rams is set in Areal.
#
# Omarchy's font is system-wide, not part of a theme. This hook gives Rams
# its typeface anyway: switching to a Rams theme saves the fonts in use and
# sets ABC Areal Mono (terminals, bar, menus) and ABC Areal (GTK app UI).
# Switching to any other theme puts the saved fonts back.
#
# Install: omarchy hook install theme-set hooks/rams-typography.sh
theme="${1:-}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/rams-theme/fonts.prev"
gs="org.gnome.desktop.interface"

mono="ABC Areal Mono"
ui="ABC Areal 11"
doc="ABC Areal 12"
gtkmono="ABC Areal Mono 11"

have_areal() { [[ -n $(fc-list "$mono" family) ]]; }

set_mono() {
  [[ $(omarchy-font-current 2>/dev/null) == "$1" ]] || omarchy-font-set "$1" >/dev/null 2>&1
}

set_gtk() {
  command -v gsettings >/dev/null || return 0
  gsettings set $gs font-name "$1"
  gsettings set $gs document-font-name "$2"
  gsettings set $gs monospace-font-name "$3"
}

if [[ $theme =~ ^rams(-|$) ]]; then
  have_areal || { echo "rams-typography: $mono is not installed" >&2; exit 0; }
  if [[ ! -f $state ]]; then
    mkdir -p "$(dirname "$state")"
    {
      echo "mono=$(omarchy-font-current)"
      echo "ui=$(gsettings get $gs font-name | tr -d "'")"
      echo "doc=$(gsettings get $gs document-font-name | tr -d "'")"
      echo "gtkmono=$(gsettings get $gs monospace-font-name | tr -d "'")"
    } >"$state"
  fi
  set_gtk "$ui" "$doc" "$gtkmono"
  set_mono "$mono"
elif [[ -f $state ]]; then
  prev_mono=$(sed -n 's/^mono=//p' "$state")
  set_gtk "$(sed -n 's/^ui=//p' "$state")" "$(sed -n 's/^doc=//p' "$state")" "$(sed -n 's/^gtkmono=//p' "$state")"
  rm -f "$state"
  [[ -n $prev_mono ]] && set_mono "$prev_mono"
fi
