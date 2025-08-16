#!/bin/bash
# OC Ops – SwiftBar (refresh every 30s via filename oc-ops.30s.sh)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CFG="$HOME/oc-dashboard/config.local.json"
JQ="/opt/homebrew/bin/jq"; [ -x "$JQ" ] || JQ="/usr/local/bin/jq"
jq() { "$JQ" "$@"; }

# Read from either flat keys or "IP allowlisting"/"other"
ROUTER_IP=$(jq -r '.router_ip // ."IP allowlisting".router_ip' "$CFG")
NAS_IP=$(jq -r '.nas_ip // ."IP allowlisting".nas_ip' "$CFG")
MUTINY_IP=$(jq -r '.server_ip // ."IP allowlisting".server_ip' "$CFG")
MUTINY_SSH=$(jq -r '.server_ssh // .other.server_ssh' "$CFG")
TX_HOSTPORT_LOCAL=$(jq -r '.tx_hostport // ."IP allowlisting".tx_hostport' "$CFG")
DASH_URL=$(jq -r '.dashboard_url // .other.dashboard_url' "$CFG")
SHORTCUT_MENU=$(jq -r '.master_shortcut // .other.master_shortcut' "$CFG")

# ---- Host checks: ICMP first, then TCP fallback
host_emoji() {
  local ip="$1"; shift
  /sbin/ping -c1 -W 1000 "$ip" >/dev/null 2>&1 && { echo "✅"; return; }
  for p in "$@"; do /usr/bin/nc -z -G 1 "$ip" "$p" >/dev/null 2>&1 && { echo "✅"; return; }; done
  echo "🟥"
}

RTR=$(host_emoji "$ROUTER_IP" 80 443 53 8291)
NAS=$(host_emoji "$NAS_IP" 445 139 80 443)
SRV=$(host_emoji "$MUTINY_IP" 22 80 443 9091)

# Transmission active torrent count via SSH to server (uses your 10.0.0.4:9091)
TORR_CNT=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "$MUTINY_SSH" \
  "transmission-remote $TX_HOSTPORT_LOCAL -l 2>/dev/null | grep -E 'Downloading|Seeding' | wc -l" 2>/dev/null)
[ -z "$TORR_CNT" ] && TORR_CNT="?"

# ---- Menubar title
echo "🏠 OC: Rtr $RTR · NAS $NAS · SRV $SRV · ⬇️ $TORR_CNT"

# ---- Dropdown
echo "---"
echo "🕹 Open OC Dashboard Menu | bash=/bin/bash param1=-lc param2='osascript -l JavaScript ~/oc-dashboard/apps/OC_Dashboard_Menu.jxa' terminal=false refresh=false"
[ -n "$DASH_URL" ] && echo "📊 OmniCore Dashboard | href=$DASH_URL"

echo "---"
echo "🔁 Restart Transmission (MUTINY-SRV) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker restart transmission\"' terminal=false refresh=true"
echo "📜 Tail Transmission Logs (100) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker logs --tail=100 transmission 2>/dev/null | tail -n 100 | pbcopy && echo Copied\\ to\\ clipboard\"' terminal=false refresh=false"

echo "---"
if command -v speedtest >/dev/null 2>&1; then
  echo "🏎 Run Speedtest (log) | bash=/bin/bash param1=-lc param2='speedtest --format=json 2>/dev/null | $JQ -r \"\\(.timestamp),\\(.download.bandwidth),\\(.upload.bandwidth),\\(.ping.latency)\" >> \"$HOME/OC_Dashboard_speedtest.csv\"' terminal=false refresh=true"
fi
[ -f "$HOME/OC_Dashboard_speedtest.csv" ] && echo "📁 Open Speedtest Log | bash=/usr/bin/open param1=$HOME/OC_Dashboard_speedtest.csv terminal=false refresh=false"

echo "---"
echo "⬇️ Update from GitHub | bash=/bin/bash param1=-lc param2='cd ~/oc-dashboard && git pull --ff-only && osascript -e \"display notification \\\"Updated\\\" with title \\\"OC Dashboard\\\"\"' terminal=false refresh=true"
echo "🔄 Refresh | refresh=true"
