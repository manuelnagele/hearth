#!/usr/bin/env bash
# One-time setup on the gaming box (also re-run by hearth-sync when deploy/ changes):
#   git clone github-hearth:manuelnagele/hearth ~/hearth && ~/hearth/deploy/install.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UNITS="$HOME/.config/systemd/user"
mkdir -p "$UNITS"
sed "s|@REPO@|$REPO|g" "$REPO/deploy/hearth-sync.service" > "$UNITS/hearth-sync.service"
systemctl --user daemon-reload

[ "${1:-}" = "--units-only" ] && exit 0

systemctl --user enable --now hearth-sync.service
systemctl --user --no-pager status hearth-sync.service | grep -E '●|Active'
