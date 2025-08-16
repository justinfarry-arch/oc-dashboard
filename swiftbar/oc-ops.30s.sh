#!/bin/bash
# OC Ops – SwiftBar (refresh every 30s)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
CFG="$HOME/oc-dashboard/config.local.json"

# --------- Read config without jq (via JXA) ----------
read_cfg() {
/usr/bin/osascript -l JavaScript <<'OSA'
ObjC.import('stdlib'); ObjC.import('Foundation');
function slurp(p){ var e=$(); var s=$.NSString.stringWithContentsOfFileEncodingError($(p), $.NSUTF8StringEncoding, e); return s?ObjC.unwrap(s):""; }
const cfgPath = $.getenv('CFG');
var o = {};
try { o = JSON.parse(slurp(cfgPath)); } catch(e) {}
var S = o["IP allowlisting"] || {}, O = o.other || {};
function pick(){ for (var i=0;i<arguments.length;i++){ var v=arguments[i]; if (v!==undefined && v!==null && v!=="") return v; } return ""; }
var out = [
  pick(o.router_ip, S.router_ip),
  pick(o.nas_ip, S.nas_ip),
  pick(o.server_ip, S.server_ip),
  pick(o.tx_hostport, S.tx_hostport),
  pick(o.portainer, S.portainer),
  pick(o.switch_ip, S.switch_ip),
  pick(o.server_ssh, O.server_ssh),
  pick(o.dashboard_url, O.dashboard_url),
  pick(o.master_shortcut, O.master_shortcut, "OC Dashboard Menu")
];
console.log(out.join("\n"));
OSA
}
IFS=$'\n' read -r ROUTER_IP NAS_IP MUTINY_IP TX_HOSTPORT_LOCAL PORTAINER_IP SWITCH_IP MUTINY_SSH DASH_URL SHORTCUT_MENU < <(read_cfg)

# --------- Host checks: ICMP first, then TCP fallback ----------
host_emoji() {
  local ip="$1"; shift
  [ -z "$ip" ] && { echo "🟥"; return; }
  /sbin/ping -c1 -W 1000 "$ip" >/dev/null 2>&1 && { echo "✅"; return; }
  for p in "$@"; do /usr/bin/nc -z -G 1 "$ip" "$p" >/dev/null 2>&1 && { echo "✅"; return; }; done
  echo "🟥"
}

RTR=$(host_emoji "$ROUTER_IP" 80 443 53 8291)
NAS=$(host_emoji "$NAS_IP" 445 139 80 443)
SRV=$(host_emoji "$MUTINY_IP" 22 80 443 9091)

# Transmission active torrent count via SSH to MUTINY-SRV
TORR_CNT=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "$MUTINY_SSH" \
  "transmission-remote $TX_HOSTPORT_LOCAL -l 2>/dev/null | grep -E 'Downloading|Seeding' | wc -l" 2>/dev/null)
[ -z "$TORR_CNT" ] && TORR_CNT="?"

# --------- Title
echo "🏠 OC: Rtr $RTR · NAS $NAS · SRV $SRV · ⬇️ $TORR_CNT"

# --------- Dropdown
echo "---"
echo "🕹 Open OC Dashboard Menu | bash=/bin/bash param1=-lc param2='osascript -l JavaScript ~/oc-dashboard/apps/OC_Dashboard_Menu.jxa' terminal=false refresh=false"
[ -n "$DASH_URL" ] && echo "📊 OmniCore Dashboard | href=$DASH_URL"
[ -n "$PORTAINER_IP" ] && echo "🧊 Portainer | href=http://$PORTAINER_IP"

echo "---"
echo "🔁 Restart Transmission (MUTINY-SRV) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker restart transmission\"' terminal=false refresh=true"
echo "📜 Tail Transmission Logs (100) | bash=/bin/bash param1=-lc param2='ssh -o BatchMode=yes $MUTINY_SSH \"docker logs --tail=100 transmission 2>/dev/null | tail -n 100 | pbcopy && echo Copied\\ to\\ clipboard\"' terminal=false refresh=false"

echo "---"
if command -v speedtest >/dev/null 2>&1; then
  echo "🏎 Run Speedtest (log) | bash=/bin/bash param1=-lc param2='speedtest --format=json 2>/dev/null | /usr/bin/osascript -l JavaScript -e \"let o=JSON.parse(require(\\\"fs\\\").readFileSync(0,\\\"utf8\\\")); console.log([new Date().toISOString(), o.download?.bandwidth||\\\"\\\", o.upload?.bandwidth||\\\"\\\", o.ping?.latency||\\\"\\\"].join(\\\",\\\"))\" >> \"$HOME/OC_Dashboard_speedtest.csv\"' terminal=false refresh=true"
fi
[ -f "$HOME/OC_Dashboard_speedtest.csv" ] && echo "📁 Open Speedtest Log | bash=/usr/bin/open param1=$HOME/OC_Dashboard_speedtest.csv terminal=false refresh=false"

echo "---"
echo "⬇️ Update from GitHub | bash=/bin/bash param1=-lc param2='cd ~/oc-dashboard && git pull --ff-only && osascript -e \"display notification \\\"Updated\\\" with title \\\"OC Dashboard\\\"\"' terminal=false refresh=true"
echo "🔄 Refresh | refresh=true"
