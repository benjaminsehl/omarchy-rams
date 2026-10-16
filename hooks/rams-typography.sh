#!/bin/bash
# theme-set hook: Rams is set in Areal, and GTK apps get Braun orange.
#
# Omarchy's font is system-wide, not part of a theme. This hook gives Rams
# its typeface anyway: switching to a Rams theme saves the fonts in use and
# sets ABC Areal Mono (terminals, bar, menus) and ABC Areal (GTK app UI).
# Switching to any other theme puts the saved fonts back.
#
# It also puts "Rams Instruments" (the bar's status icons redrawn as Braun
# instruments; installed by install.sh) into the fallback chain right after
# Areal Mono, and takes it out again on other themes.
#
# Install: omarchy hook install theme-set hooks/rams-typography.sh
theme="${1:-}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/rams-theme/fonts.prev"
gs="org.gnome.desktop.interface"

mono="ABC Areal Mono"
ui="ABC Areal 11"
doc="ABC Areal 12"
gtkmono="ABC Areal Mono 11"

fc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d"
icons_conf="$fc_dir/60-rams.conf"
restart_shell=0

# While a Rams theme is on, "Rams Instruments" goes into the fallback chain
# right after Areal Mono (conf.d runs before fonts.conf, whose prepend_first
# then puts the text face ahead of it), so the shell's icons become Braun
# instruments.
rams_conf() {
  cat <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Written by the Rams theme's rams-typography hook; removed on other themes. -->
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>Rams Instruments</string></edit>
  </match>
</fontconfig>
XML
}

icons_on() {
  rm -f "$fc_dir/60-rams-instruments.conf"   # earlier name
  local want
  want=$(rams_conf)
  [[ -f $icons_conf && $(cat "$icons_conf") == "$want" ]] && return 0
  mkdir -p "$fc_dir"
  printf '%s\n' "$want" >"$icons_conf"
  restart_shell=1
}

icons_off() {
  [[ -f $icons_conf || -f $fc_dir/60-rams-instruments.conf ]] || return 0
  rm -f "$icons_conf" "$fc_dir/60-rams-instruments.conf"
  restart_shell=1
}

# On Rams, "Calculator" in the launcher opens the ET 66 (like the calculator
# key does). A user-level omacalc.desktop overrides the system one; it is
# removed again on other themes. Omacalc itself still runs as `omacalc`.
calc_entry="${XDG_DATA_HOME:-$HOME/.local/share}/applications/omacalc.desktop"
calc_marker="X-Rams-Override=true"

calc_on() {
  [[ -f $calc_entry ]] && ! grep -q "$calc_marker" "$calc_entry" && return 0  # the user's own
  mkdir -p "$(dirname "$calc_entry")"
  cat >"$calc_entry" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ET 66
GenericName=Calculator
Comment=Pocket calculator after the Braun ET 66
Exec=omarchy-shell et66 show
Icon=omacalc
Terminal=false
Categories=Utility;Calculator;
Keywords=calculator;calc;math;arithmetic;omacalc;braun;et66;
$calc_marker
DESKTOP
}

calc_off() {
  [[ -f $calc_entry ]] && grep -q "$calc_marker" "$calc_entry" && rm -f "$calc_entry"
  return 0
}

have_areal() { [[ -n $(fc-list "$mono" family) ]]; }

# omarchy-font-set restarts the shell itself; rebuild the cache first so it
# starts with the right fonts.
set_mono() {
  [[ $(omarchy-font-current 2>/dev/null) == "$1" ]] && return 0
  (( restart_shell )) && fc-cache -f >/dev/null 2>&1
  omarchy-font-set "$1" >/dev/null 2>&1
  restart_shell=0
}

set_gtk() {
  command -v gsettings >/dev/null || return 0
  gsettings set $gs font-name "$1"
  gsettings set $gs document-font-name "$2"
  gsettings set $gs monospace-font-name "$3"
  [[ -n ${4:-} ]] && gsettings set $gs accent-color "$4" 2>/dev/null
  return 0
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
      echo "accent=$(gsettings get $gs accent-color 2>/dev/null | tr -d "'")"
    } >"$state"
  fi
  set_gtk "$ui" "$doc" "$gtkmono" orange
  icons_on
  calc_on
  set_mono "$mono"
elif [[ -f $state ]]; then
  prev_mono=$(sed -n 's/^mono=//p' "$state")
  set_gtk "$(sed -n 's/^ui=//p' "$state")" "$(sed -n 's/^doc=//p' "$state")" "$(sed -n 's/^gtkmono=//p' "$state")" "$(sed -n 's/^accent=//p' "$state")"
  rm -f "$state"
  icons_off
  calc_off
  [[ -n $prev_mono ]] && set_mono "$prev_mono"
else
  icons_off
  calc_off
fi

if (( restart_shell )); then
  fc-cache -f >/dev/null 2>&1
  omarchy-restart-shell >/dev/null 2>&1
fi
