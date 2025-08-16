#!/bin/bash
# OC Health – SwiftBar (refresh every 1m)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CFG_FILE="$HOME/oc-dashboard/config.local.json"

# --------- Read config (grouped JSON) with Python (absolute path) ----------
read_cfg() {
/usr/bin/python3 - <<'PY'
import os, json, pathlib, sys
cfg_path = os.path.expanduser(os.path.join(os.environ.get("HOME",""), "oc-dashboard", "config.local.json"))
p = pathlib.Path(cfg_path)
def blanks(n): print("\n".join([""]*n))
if not p.exists():
    blanks(4); sys.exit(0)
try:
    with open(p) as f:
        o = json.load(f)
except Exception:
    blanks(4); sys.exit(0)

S = o.get("IP allowlisting") or {}
O = o.get("other") or {}

def pick(*vals):
    for v in vals:
        if v not in (None, "", []):
            return v
    return ""

vals = [
    pick(o.get("router_ip"), S.get("router_ip")),
    pick(o.get("nas_ip"),    S.get("nas_ip")),
    pick(o.get("server_ip"), S.get("server_ip")),
    pick(o.get("server_ssh"), O.get("server_ssh")),
]
print("\n".join(vals))
PY
}
IFS=$'\n' read -r ROUTER_IP NAS_IP MUTINY_IP MUTINY_SSH < <(read_cfg)

# --------- Fallback defaults if config failed ----------
: "${ROUTER_IP:=10.0.0.1}"
: "${NAS_IP:=10.0.0.6}"
: "${MUTINY_IP:=10.0.0.4}"
: "${MUTINY_SSH:=justin@10.0.0.4}"

# Debug (to stderr)
echo "DBG => R:${ROUTER_IP} N:${NAS_IP} S:${MUTINY_IP} SSH:${MUTINY_SSH}" >&2

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
