# Runbook — eseguire le demo

Guida tecnica per far girare i container e riprodurre gli attacchi in locale.
Per il contesto e la tesi vedi il [README](./README.md).

> ⚠️ **Codice volutamente vulnerabile, a solo scopo didattico.** Token e `passwd` inclusi sono **finti**. Non esporre su reti pubbliche.

## Prerequisiti

- **Docker** + **Docker Compose**
- **Linux con AppArmor** attivo (serve solo per `app-distroless-hardened`)
- opzionale: **Marp** per rigenerare le slide (`slides/`)

## I 5 container

| servizio | porta | cosa dimostra |
|---|---|---|
| `app-classic` | 6661 | immagine classica: ogni attacco riesce, gira da root |
| `app-distroless` | 6662 | niente shell → muore solo la command injection |
| `app-distroless-hardened` | 6663 | + AppArmor + read-only + non-root: LFI su file sensibili bloccata |
| `app-go-distroless` | 6664 | binario Go statico: il primitivo fileless (`memfd_create`) è disponibile |
| `app-go-distroless-hardened` | 6665 | + Seccomp: `memfd_create` negato (EPERM) |

L'hardening è applicato a **runtime** (compose `security_opt` / `read_only` / `user`), non nell'immagine: `-hardened` usa la stessa immagine del corrispettivo non-hardened.

## Pre-flight

```bash
# 1. Carica il profilo AppArmor — RICHIESTO da app-distroless-hardened.
#    I profili AppArmor NON sopravvivono al reboot: vanno ricaricati.
sudo apparmor_parser -r -W k8s/security/apparmor-node-profile

# 2. Build + avvio di tutti e 5 i container
docker compose up --build -d

# 3. Verifica: 5 container Up su 6661-6665
docker ps
```

## Eseguire gli attacchi

Gli script colorano il risultato in base allo status HTTP: **🔴 riuscito** (male) / **🟢 bloccato** (bene), dal punto di vista del difensore.

```bash
./tests/test-node.sh app-classic                       # tutti gli attacchi Node
./tests/test-node.sh app-distroless-hardened passwd token   # selezione per nome
./tests/test-go.sh   app-go-distroless                 # attacco fileless
```

Nomi attacco — **Node**: `cmdi` · `passwd` · `token` · `conf` · `supertoken` · `eval` · `evalenv`. **Go**: `fileless`.

Gli endpoint sono gli stessi su tutte le immagini (cambia solo il risultato):

| endpoint | attacco | richiede shell? |
|---|---|---|
| `/attack/command-injection` | Command Injection | sì → distroless la blocca (`ENOENT`) |
| `/attack/path-traversal` | LFI / Path Traversal | no → distroless non la ferma |
| `/attack/eval-rce` | RCE via `eval()` | no → distroless non la ferma |
| `/attack/fileless-rce` | fileless `memfd_create` (Go) | no → serve Seccomp per negarlo |

## Cosa aspettarsi

- `app-classic` → tutto 🔴
- `app-distroless` → solo `cmdi` 🟢, il resto 🔴 (niente shell, ma il bug nel codice resta)
- `app-distroless-hardened` → `passwd`/`token` 🟢 (AppArmor), ma `conf` 🔴 (gap voluto nella blacklist) ed `eval` 🔴 (bug di codice: nessun layer runtime lo ferma)
- `app-go-distroless` → `fileless` 🔴
- `app-go-distroless-hardened` → `fileless` 🟢 (Seccomp nega `memfd_create`)

## Troubleshooting

- **`unable to apply apparmor profile: ... /attr/apparmor/exec: no such file or directory`**
  → il profilo `docker-node-hardened` non è caricato nel kernel. Esegui il pre-flight (`apparmor_parser`), poi `docker compose up -d --force-recreate app-distroless-hardened`.
- **`Cannot connect to the Docker daemon`** → variabile `DOCKER_HOST` residua: `unset DOCKER_HOST`.
- **Modifiche a `k8s/security/seccomp-go.json` non applicate** → Compose non le rileva: `docker compose up -d --force-recreate app-go-distroless-hardened`.
- **Container "fantasma" dopo un crash** → `docker rm -f <nome-container>` e poi `docker compose up -d <servizio>`.

### Rendere il profilo AppArmor persistente (opzionale)

```bash
sudo cp k8s/security/apparmor-node-profile /etc/apparmor.d/docker-node-hardened
sudo apparmor_parser -r /etc/apparmor.d/docker-node-hardened
```

## Slide

```bash
cd slides
make html   # genera slides_v4.html
make pdf    # PDF di backup
make watch  # anteprima live-reload su http://localhost:8080/
```
