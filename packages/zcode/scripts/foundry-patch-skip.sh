#!/usr/bin/env bash
# packages/core/scripts/foundry-patch-skip.sh
#
# Snooze the local-vs-canonical divergence alert for N days (default 30).
# Writes ~/.foundry/patch-skip-until: <YYYY-MM-DD>

set -uo pipefail

DAYS="${1:-30}"
# Strip --days= if passed
DAYS="${DAYS#--days=}"

UNTIL=$(date -u -v+${DAYS}d +%Y-%m-%d 2>/dev/null || date -u -d "+${DAYS} days" +%Y-%m-%d)
mkdir -p "$HOME/.foundry"
echo "$UNTIL" > "$HOME/.foundry/patch-skip-until"
echo "Snoozed divergence alerts until $UNTIL ($DAYS days)."
exit 0