#!/bin/bash
# Run the fileless (memfd_create) attack against one of the Go containers.
#
# Color legend (from the DEFENDER's point of view):
#   RED   = attack SUCCEEDED  (HTTP 2xx/3xx) -> the fileless primitive is available
#   GREEN = attack BLOCKED    (HTTP >= 400)  -> Seccomp denied memfd_create

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

usage() {
  cat <<EOF
Usage: $0 <target>

  <target> can be the SERVICE NAME or the PORT:
    app-go-distroless           -> 6664   (Go distroless: memfd_create available)
    app-go-distroless-hardened  -> 6665   (Go distroless + Seccomp: memfd_create denied)

  Examples:
    $0 app-go-distroless
    $0 app-go-distroless-hardened
EOF
  exit 1
}

[ $# -eq 0 ] && usage

case "$1" in
  app-go-distroless)          PORT=6664 ;;
  app-go-distroless-hardened) PORT=6665 ;;
  -h|--help)                  usage ;;
  [0-9]*)                     PORT="$1" ;;
  *) echo "Unknown target: '$1'"; echo; usage ;;
esac
TARGET="$1"

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

echo -e "${BOLD}=== Fileless attack against '${TARGET}' (port ${PORT}) ===${NC}"
echo -e "Legend: ${RED}${BOLD}RED = primitive available${NC} | ${GREEN}${BOLD}GREEN = Seccomp blocked${NC}"

run "Fileless RCE primitive  [fileless]  (/attack/fileless-rce)" \
    "Creates an anonymous in-RAM file with memfd_create (the fileless-malware primitive)." \
    "http://localhost:${PORT}/attack/fileless-rce"

echo ""
