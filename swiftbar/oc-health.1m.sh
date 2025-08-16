#!/bin/bash
# OC Health – SwiftBar (refresh every 1m via filename oc-health.1m.sh)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CFG="$HOME/oc-dashboard/config.local.json"
JQ="/opt/homebrew/bin/jq"; [ -x "$JQ" ] || JQ="/usr/local/bin/jq"
jq() { "$JQ" "$@"; }

ROUTER_IP=$(jq -r '.router_ip // ."IP allowlisting".router_ip' "$CFG")
NAS_IP=$(jq -r '.nas_ip // ."IP allowlisting".nas_ip' "$CFG")
MUTINY_IP=$(jq -r '.server_ip // ."IP allowlisting".server_ip' "$CFG")
MUTINY_SSH=$(jq -r '.server_ssh // .other.server_ssh' "$CFG")

host_ok() {
  local ip="$1"; shift
  /sbin/ping -c1 -W 1000 "$ip" >/dev/null 2>&1 && { echo "✅"; return; }
  for p in "$@"; do /usr/bin/nc -z -G 1 "$ip" "$p" >/dev/null 2>&1 && { echo "✅"; return; }; done
  echo "🟥"
}

RTR=$(host_ok "$ROUTER_IP" 80 443 53 8291)
NAS=$(host_ok "$NAS_IP" 445 139 80 443)
SRV=$(host_ok "$MUTINY_IP" 22 80 443 9091)

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
