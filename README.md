# Container at War — Distroless & Hardening

Codice demo e slide del talk **"Container at War: Distroless, hardening e il mito del «più sicuro»"** — di Gabriele Fontana, [Come to Code 2026](https://cometocode.it), Pignola (PZ).

> **Tesi:** «Più sicuro» non vuol dire «sicuro». Le immagini Distroless riducono la superficie d'attacco ma non bastano: la sicurezza è una catena, e va difesa a più livelli (AppArmor, Seccomp, RBAC, difesa in profondità).

## ⚠️ Codice volutamente vulnerabile

Questo repository contiene un'applicazione **intenzionalmente insicura** (Path Traversal / LFI, command injection, `eval` RCE) a **solo scopo didattico**. Serve a dimostrare tecniche di attacco e le relative mitigazioni.

**Non deployare in produzione. Non esporre su reti pubbliche.** Il token e il file `passwd` inclusi sono **finti**, creati per la demo.

## Struttura

```
src/demo-node/     App Node.js (Fastify) vulnerabile + Dockerfile distroless e classico
docker-compose.yml Tre scenari: classica (8079), distroless (8080), hardened (8081)
k8s/               Manifest Kubernetes + profilo AppArmor + mock token/passwd per la demo
tests/             Script di verifica degli attacchi
slides/            Slide del talk (Marp): slides_v3.md è la versione corrente
Makefile           Target per generare le slide (slides / slides-pdf / slides-watch)
```

## Demo rapida (Docker)

```bash
docker compose up --build -d app-classic app-distroless
# app-classic (6661):    /attack/command-injection RIESCE (c'è /bin/sh)
# app-distroless (6662): /attack/command-injection FALLISCE (ENOENT, niente shell)
#                        /attack/path-traversal e /attack/eval-rce RIESCONO comunque
./tests/test-node.sh app-distroless
docker compose down
```

Endpoint disponibili (stesso path su tutte le immagini, cambia solo il risultato):

| Endpoint | Attacco | Richiede shell? |
|---|---|---|
| `/attack/command-injection` | Command Injection classica | Sì → distroless la blocca (`ENOENT`) |
| `/attack/path-traversal` | LFI / Path Traversal | No → distroless non la ferma |
| `/attack/eval-rce` | RCE via `eval()` | No → distroless non la ferma |

Guida passo-passo per AppArmor su Minikube in `k8s/` e nelle slide.

## Slide

```bash
make slides        # genera slides/slides_v3.html
make slides-pdf    # genera il PDF (backup offline)
make slides-watch  # anteprima live con presenter mode
```

## Crediti e riferimenti

- Security review assistita da AI: **Argus** di [Davide Imola](https://www.davideimola.dev/) (RedCarbon).
- Riferimenti tecnici: NIST SP 800-190, Kubernetes Cloud Native Security (4C), OWASP.

## Licenza

MIT — usa pure il materiale, ma ricorda: è codice vulnerabile per didattica.
