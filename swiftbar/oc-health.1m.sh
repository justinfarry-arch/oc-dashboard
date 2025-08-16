#!/bin/bash
# OC Health – SwiftBar (refresh every 1m via filename oc-health.1m.sh)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CFG="$HOME/oc-dashboard/config.local.json"
jq() { /opt/homebrew/bin/jq "$@"; }

ROUTER_IP=$(jq -r '.router_ip' "$CFG" 2>/dev/null)
NAS_IP=$(jq -r '.nas_ip' "$CFG" 2>/dev/null)
MUTINY_IP=$(jq -r '.server_ip' "$CFG" 2>/dev/null)
MUTINY_SSH=$(jq -r '.server_ssh' "$CFG" 2>/dev/null)

ok() { ping -c1 -W 200 "$1" >/dev/null 2>&1 && echo "✅" || echo "🟥"; }

RTR=$(ok "$ROUTER_IP"); NAS=$(ok "$NAS_IP"); SRV=$(ok "$MUTINY_IP")

echo "🩺 $RTR$NAS$SRV"
echo "---"
echo "Router (SYSOP-GW): $RTR ($ROUTER_IP)"
echo "NAS (DATAVAULT-NAS): $NAS ($NAS_IP)"
echo "Server (MUTINY-SRV): $SRV ($MUTINY_IP)"

DF=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "$MUTINY_SSH" "df -h / | tail -1" 2>/dev/null)
[ -n "$DF" ] && echo "MUTINY-SRV /: ${DF}" || echo "MUTINY-SRV /: (ssh unavailable)"

echo "---"
echo "Open OC Dashboard | bash=/bin/bash param1=-lc param2='osascript -l JavaScript ~/oc-dashboard/apps/OC_Dashboard_Menu.jxa' terminal=false refresh=false"
echo "Refresh | refresh=true"
