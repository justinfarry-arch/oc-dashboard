#!/bin/bash
# OC Ops – SwiftBar (refresh every 30s via filename oc-ops.30s.sh)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CFG="$HOME/oc-dashboard/config.local.json"
jq() { /opt/homebrew/bin/jq "$@"; }

ROUTER_IP=$(jq -r '.router_ip' "$CFG" 2>/dev/null)
NAS_IP=$(jq -r '.nas_ip' "$CFG" 2>/dev/null)
MUTINY_IP=$(jq -r '.server_ip' "$CFG" 2>/dev/null)
MUTINY_SSH=$(jq -r '.server_ssh' "$CFG" 2>/dev/null)
TX_HOSTPORT_LOCAL=$(jq -r '.tx_hostport' "$CFG" 2>/dev/null)
DASH_URL=$(jq -r '.dashboard_url' "$CFG" 2>/dev/null)
SHORTCUT_MENU=$(jq -r '.master_shortcut' "$CFG" 2>/dev/null)

ping_emoji() { ping -c1 -W 200 "$1" >/dev/null 2>&1 && echo "✅" || echo "🟥"; }

RTR=$(ping_emoji "$ROUTER_IP")
NAS=$(ping_emoji "$NAS_IP")
SRV=$(ping_emoji "$MUTINY_IP")

TORR_CNT=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "$MUTINY_SSH" \
  "transmission-remote $TX_HOSTPORT_LOCAL -l 2>/dev/null | grep -E 'Downloading|Seeding' | wc -l" 2>/dev/null)
[ -z "$TORR_CNT" ] && TORR_CNT="?"

echo "🏠 OC: Rtr $RTR · NAS $NAS · SRV $SRV · ⬇️ $TORR_CNT"
echo "---"
echo "🕹 Open OC Dashboard Menu | bash=/bin/bash param1=-lc param2='osascript -l JavaScript ~/oc-dashboard/apps/OC_Dashboard_Menu.jxa' terminal=false refresh=false"
echo "📊 OmniCore Dashboard | href=$DASH_URL"

echo "---"
echo "🔁 Restart Transmission (MUTINY-SRV) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker restart transmission\"' terminal=false refresh=true"
echo "📜 Tail Transmission Logs (100) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker logs --tail=100 transmission 2>/dev/null | tail -n 100 | pbcopy && echo Copied\\ to\\ clipboard\"' terminal=false refresh=false"

echo "---"
if command -v speedtest >/dev/null 2>&1; then
  echo "🏎 Run Speedtest (log) | bash=/bin/bash param1=-lc param2='speedtest --format=json 2>/dev/null | jq -r \"\\(.timestamp),\\(.download.bandwidth),\\(.upload.bandwidth),\\(.ping.latency)\" >> \"$HOME/OC_Dashboard_speedtest.csv\"' terminal=false refresh=true"
fi
[ -f "$HOME/OC_Dashboard_speedtest.csv" ] && echo "📁 Open Speedtest Log | bash=/usr/bin/open param1=$HOME/OC_Dashboard_speedtest.csv terminal=false refresh=false"

echo "---"
echo "⬇️ Update from GitHub | bash=/bin/bash param1=-lc param2='cd ~/oc-dashboard && git pull --ff-only && osascript -e \"display notification \\\"Updated\\\" with title \\\"OC Dashboard\\\"\"' terminal=false refresh=true"
echo "🔄 Refresh | refresh=true"
