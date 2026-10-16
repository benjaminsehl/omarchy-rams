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

icons_conf="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/60-rams-instruments.conf"
restart_shell=0

icons_on() {
  [[ -n $(fc-list "Rams Instruments" family) ]] || return 0
  [[ -f $icons_conf ]] && return 0
  mkdir -p "$(dirname "$icons_conf")"
  cat >"$icons_conf" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Written by the Rams theme's rams-typography hook; removed on other themes.
     conf.d runs before fonts.conf, whose prepend_first then puts the text face
     ahead of this one: ABC Areal Mono, Rams Instruments, then the rest. -->
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any"><string>monospace</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>Rams Instruments</string></edit>
  </match>
</fontconfig>
XML
  restart_shell=1
}

icons_off() {
  [[ -f $icons_conf ]] || return 0
  rm -f "$icons_conf"
  restart_shell=1
}

have_areal() { [[ -n $(fc-list "$mono" family) ]]; }

# omarchy-font-set restarts the shell itself.
set_mono() {
  [[ $(omarchy-font-current 2>/dev/null) == "$1" ]] && return 0
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
  set_mono "$mono"
elif [[ -f $state ]]; then
  prev_mono=$(sed -n 's/^mono=//p' "$state")
  set_gtk "$(sed -n 's/^ui=//p' "$state")" "$(sed -n 's/^doc=//p' "$state")" "$(sed -n 's/^gtkmono=//p' "$state")" "$(sed -n 's/^accent=//p' "$state")"
  rm -f "$state"
  icons_off
  [[ -n $prev_mono ]] && set_mono "$prev_mono"
else
  icons_off
fi

if (( restart_shell )); then
  fc-cache -f >/dev/null 2>&1
  omarchy-restart-shell >/dev/null 2>&1
fi
