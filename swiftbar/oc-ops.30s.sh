cat > ~/oc-dashboard/swiftbar/oc-ops.30s.sh <<'SH'
#!/bin/bash
# OC Ops – SwiftBar (refresh every 30s)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# choose a working python3
PYTHON="$(command -v python3)"
[ -x "$PYTHON" ] || PYTHON="/opt/homebrew/bin/python3"
[ -x "$PYTHON" ] || PYTHON="/usr/bin/python3"

# --------- Read config (grouped JSON) with Python (absolute path) ----------
read_cfg() {
"$PYTHON" - <<'PY'
import os, json, pathlib, sys
cfg_path = os.path.expanduser(os.path.join(os.environ.get("HOME",""), "oc-dashboard", "config.local.json"))
p = pathlib.Path(cfg_path)
def blanks(n): print("\n".join([""]*n))
if not p.exists():
    blanks(9); sys.exit(0)
try:
    with open(p) as f:
        o = json.load(f)
except Exception:
    blanks(9); sys.exit(0)

S = o.get("IP allowlisting") or {}
O = o.get("other") or {}

def pick(*vals):
    for v in vals:
        if v not in (None, "", []):
            return v
    return ""

vals = [
    pick(o.get("router_ip"),     S.get("router_ip")),
    pick(o.get("nas_ip"),        S.get("nas_ip")),
    pick(o.get("server_ip"),     S.get("server_ip")),
    pick(o.get("tx_hostport"),   S.get("tx_hostport")),
    pick(o.get("portainer"),     S.get("portainer")),
    pick(o.get("switch_ip"),     S.get("switch_ip")),
    pick(o.get("server_ssh"),    O.get("server_ssh")),
    pick(o.get("dashboard_url"), O.get("dashboard_url")),
    pick(o.get("master_shortcut"), O.get("master_shortcut"), "OC Dashboard Menu")
]
print("\n".join(vals))
PY
}

IFS=$'\n' read -r ROUTER_IP NAS_IP MUTINY_IP TX_HOSTPORT_LOCAL PORTAINER_IP SWITCH_IP MUTINY_SSH DASH_URL SHORTCUT_MENU < <(read_cfg)

# --------- Fallback defaults if config failed ----------
: "${ROUTER_IP:=10.0.0.1}"
: "${NAS_IP:=10.0.0.6}"
: "${MUTINY_IP:=10.0.0.4}"
: "${TX_HOSTPORT_LOCAL:=10.0.0.4:9091}"
: "${MUTINY_SSH:=justin@10.0.0.4}"

# Debug (stderr so SwiftBar ignores it) — this MUST print when you run the script in Terminal
echo "DBG => R:${ROUTER_IP} N:${NAS_IP} S:${MUTINY_IP} TX:${TX_HOSTPORT_LOCAL} SSH:${MUTINY_SSH} URL:${DASH_URL}" >&2

# --------- Host checks: ICMP then TCP fallback ----------
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
  echo "🏎 Run Speedtest (log) | bash=/bin/bash param1=-lc param2='speedtest --format=json 2>/dev/null | \"$PYTHON\" - \"$HOME/OC_Dashboard_speedtest.csv\" <<PY\nimport sys, json, datetime\nj=json.load(sys.stdin)\nrow=\",\".join([\n  datetime.datetime.utcnow().isoformat()+\"Z\",\n  str(j.get(\"download\",{}).get(\"bandwidth\",\"\")),\n  str(j.get(\"upload\",{}).get(\"bandwidth\",\"\")),\n  str(j.get(\"ping\",{}).get(\"latency\",\"\"))\n])\nopen(sys.argv[1],\"a\").write(row+\"\\n\")\nPY' terminal=false refresh=true"
fi
[ -f "$HOME/OC_Dashboard_speedtest.csv" ] && echo "📁 Open Speedtest Log | bash=/usr/bin/open param1=$HOME/OC_Dashboard_speedtest.csv terminal=false refresh=false"

echo "---"
echo "⬇️ Update from GitHub | bash=/bin/bash param1=-lc param2='cd ~/oc-dashboard && git pull --ff-only && osascript -e \"display notification \\\"Updated\\\" with title \\\"OC Dashboard\\\"\"' terminal=false refresh=true"
echo "🔄 Refresh | refresh=true"
SH
