#!/bin/bash
# OC Health – SwiftBar (refresh every 1m)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
CFG="$HOME/oc-dashboard/config.local.json"
export CFG

# --------- Read config without jq ----------
read_cfg() {
/usr/bin/osascript -l JavaScript <<'OSA'
ObjC.import('stdlib'); ObjC.import('Foundation');
function slurp(p){ var e=$(); var s=$.NSString.stringWithContentsOfFileEncodingError($(p), $.NSUTF8StringEncoding, e); return s?ObjC.unwrap(s):""; }
const cfgPath = $.getenv('CFG');
var o = {}; try { o = JSON.parse(slurp(cfgPath)); } catch(e) {}
var S = o["IP allowlisting"] || {}, O = o.other || {};
function pick(){ for (var i=0;i<arguments.length;i++){ var v=arguments[i]; if (v!==undefined && v!==null && v!=="") return v; } return ""; }
var out = [
  pick(o.router_ip, S.router_ip),
  pick(o.nas_ip, S.nas_ip),
  pick(o.server_ip, S.server_ip),
  pick(o.server_ssh, O.server_ssh)
];
console.log(out.join("\n"));
OSA
}
IFS=$'\n' read -r ROUTER_IP NAS_IP MUTINY_IP MUTINY_SSH < <(read_cfg)

# --------- Host checks with TCP fallback ----------
host_ok() {
  local ip="$1"; shift
  [ -z "$ip" ] && { echo "🟥"; return; }
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
