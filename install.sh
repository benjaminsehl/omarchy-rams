#!/bin/bash
# Installs Rams and Rams Dark, the live Braun clock, and the Areal
# typography hook. Re-running is safe. Fonts are separate (see README).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
themes="$HOME/.config/omarchy/themes"
plugins="$HOME/.config/omarchy/plugins"

link() {
  if [[ -e $2 && ! -L $2 ]]; then
    echo "$2 exists and is not a link; leaving it alone" >&2
    return 1
  fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
}

link "$here" "$themes/rams"
link "$here/variants/dark" "$themes/rams-dark"
link "$here/extras/braun-clock" "$plugins/sehl.braun-clock"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable sehl.braun-clock >/dev/null
omarchy plugin enable omarchy.background >/dev/null 2>&1 || true
omarchy hook install theme-set "$here/hooks/rams-typography.sh" >/dev/null

echo "Installed Rams. Apply it with: omarchy theme set rams   (or rams-dark)"
[[ -n $(fc-list "ABC Areal Mono" family) ]] || echo "Note: ABC Areal is not installed yet; see README."
