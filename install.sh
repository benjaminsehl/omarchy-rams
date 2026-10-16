#!/bin/bash
# Installs Rams and Rams Dark, the live clock (desktop, screensaver), the
# Rams lock screen, the bar's instrument icons, the ET 66 calculator and the
# typography hook.
# Re-running is safe. ABC Areal is separate (see README).
#
#   ./install.sh            everything
#   ./install.sh --no-lock  keep the stock lock screen
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
themes="$HOME/.config/omarchy/themes"
plugins="$HOME/.config/omarchy/plugins"
fonts="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/RamsInstruments"
with_lock=1
[[ ${1:-} == --no-lock ]] && with_lock=0

link() {
  if [[ -e $2 && ! -L $2 ]]; then
    echo "$2 exists and is not a link; leaving it alone" >&2
    return 1
  fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
}

# Themes, clock plugin, icon font.
link "$here" "$themes/rams"
link "$here/variants/dark" "$themes/rams-dark"
link "$here/extras/braun-clock" "$plugins/sehl.braun-clock"
link "$here/extras/et66" "$plugins/sehl.et66"
mkdir -p "$fonts"
ln -sfn "$here/extras/instruments/RamsInstruments.otf" "$fonts/RamsInstruments.otf"
fc-cache -f "$fonts" >/dev/null

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable sehl.braun-clock >/dev/null
omarchy plugin enable sehl.et66 >/dev/null
omarchy plugin enable omarchy.background >/dev/null 2>&1 || true

# Lock screen: a clone of omarchy.lock with only its view patched.
if (( with_lock )); then
  lock="$plugins/${USER:-$(id -un)}.lock"
  [[ -d $lock ]] || omarchy plugin clone omarchy.lock >/dev/null
  python3 "$here/extras/lock/patch-lockview.py" "$lock/LockView.qml"
fi

omarchy hook install theme-set "$here/hooks/rams-typography.sh" >/dev/null

# Bring the fonts in line with whatever theme is active now.
bash "$HOME/.config/omarchy/hooks/theme-set.d/rams-typography.sh" \
  "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)"

echo "Installed Rams. Apply it with: omarchy theme set rams   (or rams-dark)"
[[ -n $(fc-list "ABC Areal Mono" family) ]] || echo "Note: ABC Areal is not installed yet; see README."
