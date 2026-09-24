---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
style: |
  section {
    justify-content: center;
    font-size: 26px;
  }
  section.lead h1 { font-size: 54px; }
  code { font-size: 0.8em; }
  .small { font-size: 0.7em; color: #555; }
  .tag { background:#111; color:#fff; padding:2px 10px; border-radius:6px; font-size:0.7em; }
---

<!--
SPEAKER NOTES — LEGENDA
- Ogni slide ha una nota (questo blocco HTML) con: cosa dire, cosa fare, timing.
- DEMO = esecuzione live SOLO su Docker (docker-compose). Kubernetes viene NOMINATO/MOSTRATO, non eseguito.
- CODE = commento al codice live (non live-coding: il codice è già a schermo).
- Tesi ricorrente da ripetere 3-4 volte: «Più sicuro» non vuol dire «sicuro».
- Budget totale ~45 min. I minuti indicati sono cumulativi indicativi.
- REGOLA: tieni pronto un video di backup di ogni DEMO. Se si rompe, mandi il video e vai avanti.
-->

# Container at War
## Distroless, hardening e il mito del «più sicuro»
<br>

<span class="small">Come to Code 2026 · Pignola · Gabriele Fontana </span>

<!--
[0:00 → 0:45] Apertura.
"Questo talk parla di una parola pericolosa: SICURO. E del suo cugino ancora più pericoloso: PIÙ sicuro."
Presentati in 15 secondi. Non dilungarti.
-->

---

## La tesi, in una frase

# «Più sicuro» **non vuol dire** «sicuro».

Le buzzword sono un **punto di partenza**, non un threat model.

<!--
[0:45 → 2:00] Il patto col pubblico.
Dì: "Oggi useremo Distroless come caso-studio, ma il messaggio vale per tre frasi che sentiamo ogni giorno:
1) 'È distroless, quindi è sicuro'
2) 'Sono su un managed / GKE, quindi sono protetto'
3) 'Uso questa libreria perché è più sicura'.
Le smontiamo una a una. Non per dire che sono inutili — ma che sono l'INIZIO del ragionamento, non la fine."
Anticipa il formato: "Vedremo codice vero e qualche attacco eseguito dal vivo. Su Docker, per tenere le cose semplici — ma tutto questo gira identico su Kubernetes."
-->

---

## 1. Il mito Distroless

Immagini *distroless* = solo la tua app e le sue dipendenze runtime.

- ❌ Niente shell (`/bin/sh`)
- ❌ Niente package manager (`apt`, `apk`)
- ❌ Niente tool (`curl`, `wget`, `ls`)

<!--
[2:00 → 4:00]
Spiega cos'è distroless in modo semplice. "Prendi Ubuntu, togli tutto quello che non serve a far girare la tua app. Resta quasi solo il runtime."
Fai l'esempio pratico: "Provate a fare `kubectl exec` in un pod distroless: non c'è la shell, non entrate. All'inizio spiazza."
-->

---

## Perché distroless è nata (ed è un BENE)

- 🎯 Superficie d'attacco ridotta
- 🐛 **Meno CVE** (meno pacchetti = meno vulnerabilità note)
- 📦 Immagine più piccola, deploy più veloci, meno da mantenere

> Distroless è **necessario ma non sufficiente**.

<!--
[importante — onestà intellettuale]
NON vogliamo che il pubblico esca pensando "distroless è inutile". È il contrario.
Dì chiaramente: "Se non state usando immagini minimali, iniziate. Fanno bene davvero.
Il punto del talk è un altro: risolvono UN problema, non IL problema."
Ripeti il claim di marketing: "Il messaggio implicito però è: 'minimale = sicuro'. È lì che caschiamo."
-->

---

## La domanda del talk

Se tolgo la shell...
# ...ho tolto l'attaccante?

Verifichiamolo. Con il codice, non con gli slogan.

<!--
[4:00 → 4:30] Ponte verso la prima demo. Tono da "mettiamo alla prova il claim".
-->

---

## 2. Round 1 — La falsa vittoria
### Command Injection

```js
// src/demo-node/server.js  —  endpoint /attack/command-injection
fastify.get('/attack/command-injection', (req, reply) => {
  const ip = req.query.ip || '8.8.8.8';
  exec(`ping -c 1 ${ip}`, (err, stdout) => {   // <-- exec = /bin/sh -c
    return reply.send(err ? `[FAILED] ${err.message}` : stdout);
  });
});
```

<span class="tag">CODE</span> Commento al codice live

<!--
[4:30 → 6:00] CODE.
Commenta: "Classico bug da manuale. Concateno input utente dentro un comando. `exec` di Node NON esegue il binario direttamente: apre `/bin/sh -c '...'`. Tenete a mente questo dettaglio."
Payload che mostreremo: ip = 8.8.8.8;id  → su immagine classica esegue anche `id` (uid=0(root)).
-->

---

## Demo — immagine classica vs distroless

<span class="tag">DEMO Docker</span>

```bash
# L'attacco vero è un curl all'endpoint vulnerabile (payload: 8.8.8.8;id)
curl -sG "http://localhost:6661/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"
#  -> HTTP 200  ping + id eseguiti → uid=0(root)          🔴  classic: c'è /bin/sh

curl -sG "http://localhost:6662/attack/command-injection" --data-urlencode "ip=8.8.8.8;id"
#  -> HTTP 500  [FAILED] spawn /bin/sh ENOENT             🟢  distroless: niente shell
```

<span class="small">Scorciatoia per le demo successive: <code>./tests/test-node.sh app-classic cmdi</code> — è lo <b>stesso</b> <code>curl</code>, colorato 🔴/🟢 in base allo status HTTP.</span>

<!--
[6:00 → 8:00] DEMO su Docker (docker-compose up già avviato prima del talk).
Round 1 lo faccio A MANO col curl, per mostrare che è un attacco vero e nulla è nascosto.
Dico: "ho un curl a un URL, punto. Poi per le prossime demo uso uno script che è lo stesso curl, solo colorato di rosso/verde per leggere il risultato al volo."
Comando a mano (classic, 6661): curl -sG ".../attack/command-injection" --data-urlencode "ip=8.8.8.8;id" → HTTP 200, id gira, uid=0(root).
Poi contro distroless (6662): stesso curl → HTTP 500, [FAILED] spawn /bin/sh ENOENT.
Dalla demo 2 in poi uso lo script: ./tests/test-node.sh <target> <attacco> — il colore lo decide dallo status HTTP (RED = riuscito, GREEN = bloccato).
Battuta: "Distroless 1 - Attaccante 0. Vittoria! ... Fine del talk? Grazie a tutti?"
Pausa comica, poi: "No. Perché ho appena barato con voi."
-->

---

## Cos'è successo davvero?

- ✅ Distroless ha rotto **la kill-chain classica** (spawn di shell)
- ⚠️ Ma la **vulnerabilità è ancora lì**
- ⚠️ È fallita *l'exploitation*, non è sparito il bug

# «Più sicuro» ≠ «sicuro»

<!--
[8:00 → 9:00] Il primo ribaltone concettuale.
Dì: "Ho scelto apposta un attacco che ha BISOGNO della shell. Ho truccato il match.
Distroless ha fermato quel vettore. Non ha reso il codice corretto.
E se trovo un attacco che NON ha bisogno della shell?"
-->

---

## 3. La sicurezza è una **catena**
### Le 4C della Cloud Native Security

**Code** → **Container** → **Cluster** → **Cloud**

Distroless lavora su **un solo anello** (Container).
Il bug della demo vive nell'anello **Code**.

<span class="small">Fonte: Kubernetes — Overview of Cloud Native Security</span>

<!--
[9:00 → 11:00]
Le 4C sono un modello ufficiale K8s: citalo, ti dà autorevolezza.
"Ogni anello ha le sue difese. Distroless è una difesa dell'anello Container.
Il mio bug — la command injection, l'LFI che vedremo — vive nell'anello Code.
Nessuna quantità di hardening del Container ripara un anello che sta più in alto."
Cita OWASP Top 10: injection, path traversal, deserializzazione insicura — sono tutti bug di 'Code'.
-->

---

## 4. Round 2 — L'illusione cade
### Local File Inclusion / Path Traversal

```js
// endpoint /attack/path-traversal
fastify.get('/attack/path-traversal', async (req, reply) => {
  return reply.send(
    fs.readFileSync(req.query.file, 'utf8')   // <-- nessuna validazione
  );
});
```

<span class="tag">CODE</span> Node **non ha bisogno di bash** per leggere un file.

<!--
[11:00 → 12:30] CODE.
"Qui non c'è nessuna shell coinvolta. `fs.readFileSync` è codice Node nativo.
L'attaccante controlla il path. Distroless non può fare NULLA: sto usando una funzione legittima del runtime."
Prepara il pubblico all'easter egg.
-->

---

## Demo — leggo `/etc/passwd`

<span class="tag">DEMO Docker</span>

```bash
./tests/test-node.sh app-distroless passwd
```

```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
root:x:0:0:root:/root:/bin/bash
...
darth_vader:x:66:66:Sith Lord:/death_star:/bin/force_choke
neo:x:101:101:The One:/matrix:/bin/fly
```

<!--
[12:30 → 14:00] DEMO su Docker (distroless, porta 6662). Comando: ./tests/test-node.sh app-distroless passwd.
Lascia che il pubblico legga l'easter egg. Momento leggero: "Sul mio server gira anche Darth Vader, shell /bin/force_choke."
Poi serio: "Ok, ho letto /etc/passwd. Chi se ne frega. Ora alziamo la posta."
-->

---

## Demo — il danno vero: il token del cluster

<span class="tag">DEMO Docker</span>

```bash
./tests/test-node.sh app-distroless token
```
```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6...
```

Service Account Token → **movimento laterale nel cluster**.
Nessuna shell. Solo `fs.readFileSync`.

<span class="small">(Token FINTO montato per la demo — meccanismo reale, valore innocuo.)</span>

<!--
[14:00 → 15:30] DEMO. Comando: ./tests/test-node.sh app-distroless token.
Mostra il JWT, decodificalo su jwt.io (assicurati sia il token FINTO valido, non quello malformato del repo).
Spiega il blast radius: "Con un token di service account permissivo, da qui parlo con l'API server del cluster.
Da un bug in UNA app, potenzialmente muovo su tutto il namespace."
DILLO: "Il token è finto, ma il meccanismo è reale al 100%."
-->

---

## «E su Kubernetes?»

<span class="tag">K8s — mostrato, non eseguito</span>

```yaml
# k8s/node-pods.yaml  (estratto)
spec:
  containers:
  - name: app
    image: demo-node-lfi:latest
```

Lo stesso identico attacco. Cambia solo *dove* gira il pod.
Il token è montato in `/var/run/secrets/...` **da Kubernetes stesso**.

<!--
[15:30 → 16:30] K8s NOMINATO.
Non eseguire nulla: mostra il manifest a schermo.
"Ho fatto la demo su Docker per semplicità, ma in un cluster è identico — anzi, è PEGGIO,
perché è Kubernetes a montare quel token nel filesystem del pod, di default, in ogni pod."
Aggancio: "Quindi il managed mi salva? Ci arriviamo tra poco. Prima, il colpo di grazia."
-->

---

## 5. Round 3 — RCE **senza** shell
### Il runtime *è* la shell

```js
// endpoint /attack/eval-rce
fastify.get('/attack/eval-rce', (req, reply) => {
  const result = eval(req.query.code);   // <-- esecuzione arbitraria JS
  return reply.send(`RCE result: ${result}`);
});
```

<span class="tag">CODE</span> Non mi serve `/bin/sh`: mi serve il tuo **interprete**.

<!--
[16:30 → 18:00] CODE.
"L'ossessione per 'togliere la shell' parte da un presupposto: che l'attaccante voglia UNA shell.
Ma se la tua app è un interprete — Node, Python, Ruby — l'interprete È già una shell.
`eval` esegue qualsiasi JS: posso fare require('fs'), require('child_process')... dentro il processo Node,
senza mai toccare /bin/sh."
-->

---

## Demo — esecuzione di codice arbitrario

<span class="tag">DEMO Docker</span>

```bash
./tests/test-node.sh app-distroless eval
```
```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
RCE result: 2
```

Payload dello script: `code=1+1` — banale apposta, per essere ripetibile sul palco.
Ma è la STESSA strada di `require('fs').readFileSync(token)`.
RCE reale su **distroless**. Zero shell coinvolte.

<!--
[18:00 → 19:30] DEMO (distroless). Comando: ./tests/test-node.sh app-distroless eval.
Questa è la demo RCE più solida: dipende solo dal runtime Node, non dal kernel della VM.
Lo script manda un payload innocuo (1+1) per essere sicuro e ripetibile live, ma sottolinea a voce:
"eval esegue QUALSIASI JS. Lo stesso `eval` potrebbe fare require('fs').readFileSync sul token che avete visto prima."
Takeaway forte: "Distroless toglie la SHELL. Non toglie il RUNTIME. E il runtime, per un interprete, è tutto ciò che serve."
Ripeti la tesi: «Più sicuro» non vuol dire «sicuro».
-->

---

## 6. «Ma io compilo un binario statico!»
### Go, esecuzione *fileless*

```go
// memfd_create: file anonimo, vive SOLO in RAM (mai su disco)
fd, _ := unix.MemfdCreate("demo", unix.MFD_CLOEXEC)
```

<span class="tag">DEMO Docker</span>

```bash
./tests/test-go.sh app-go-distroless
```
```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
[SUCCEEDED] fileless primitive available
```

Nessun file su disco. Read-only FS inutile qui. AppArmor guarda i **file**, non le syscall: non lo vede.

<!--
[19:30 → 22:30] DEMO su Docker (Go, porta 6664). Ora LIVE — il demo Go+Seccomp funziona, niente più solo commento.
"Un'altra buzzword: 'binario statico minimale, non c'è niente da attaccare'. Guardiamo."
Comando: ./tests/test-go.sh app-go-distroless.
"memfd_create crea un file ANONIMO che vive solo in RAM: non tocca mai il disco. È il primitivo che usa il malware
fileless vero. Un read-only filesystem qui non serve a NIENTE — non sto scrivendo sul disco. E AppArmor? Guarda i
FILE, non le syscall: è cieco su questo."
Onestà (importante): "L'handler è BENIGNO apposta: crea il file in RAM e vi dice che il primitivo è disponibile.
Non esegue un payload attaccante — mi fermo qui per restare nei tempi e non portare un exploit reale sul palco.
Il punto di sicurezza è che il primitivo ESISTE, non serve altro."
-->

---

## Il punto dei tre round

| Buzzword | Realtà |
|---|---|
| "Niente shell = sicuro" | Il runtime esegue lo stesso |
| "Read-only = sicuro" | L'LFI è in *lettura*; il fileless è in *RAM* |
| "Binario minimale = sicuro" | Le syscall bastano |

# Ho bisogno di difese al **livello giusto**.

<!--
[22:30 → 23:30] Riepilogo prima della svolta positiva.
"Fin qui vi ho depresso. Ora la buona notizia: le difese esistono. Ma NON sono nell'immagine.
Sono un anello più in basso — nel kernel."
-->

---

## 7. L'hardening (la difesa vera)
### Un container **non ha** un kernel

AppArmor e Seccomp sono moduli del **kernel dell'host** (il nodo).
L'immagine distroless non li conosce: è il **nodo** che intercetta il processo.

<!--
[23:30 → 25:00]
Concetto chiave spesso frainteso: "Il container condivide il kernel dell'host.
Non c'è un kernel 'dentro' l'immagine. Quindi le difese kernel — AppArmor, Seccomp —
vivono sul NODO, non nell'immagine. Ecco perché distroless da solo non può offrirle."
-->

---

## AppArmor — controllo sull'accesso ai file

```
# k8s/security/apparmor-node-profile (estratto)
deny /etc/passwd mrw,
deny /etc/shadow mrw,
deny /var/run/secrets/kubernetes.io/serviceaccount/** mrw,
```

```bash
./tests/test-node.sh app-distroless-hardened passwd token
```
```
[ATTACK BLOCKED - HTTP 500]                         🟢
Read error: EACCES
```

<span class="tag">DEMO Docker</span> Ritento l'LFI sul container *hardened* → **EACCES** 🎉

<span class="small">Nota onesta: qui uso una blacklist per didattica. In produzione → allowlist (vedi slide dopo).</span>

<!--
[25:00 → 27:00] DEMO su Docker (container app-distroless-hardened, porta 6663, con security_opt apparmor).
Comando: ./tests/test-node.sh app-distroless-hardened passwd token — rilancia le stesse due LFI di prima, ora contro 6663.
Entrambe tornano VERDI: "Read error: EACCES". "Il kernel dell'host ha intercettato la readFileSync di Node PRIMA che leggesse il file."
Onestà: "Sto usando una blacklist — 'nega questi file'. È fragile: dimentichi un file e sei fregato. Tra un attimo vi mostro esattamente cosa succede quando dimentichi."
K8s: "Su Kubernetes stesso profilo, via securityContext.appArmorProfile (da 1.30)." — mostra riga, non eseguire.
-->

---

## AppArmor — il buco della blacklist

<span class="tag">DEMO Docker</span>

```bash
./tests/test-node.sh app-distroless-hardened conf
```
```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
```

Stesso LFI, file diverso: `/etc/come-to-code.conf`.
La blacklist **non lo conosce** → nessun `deny`, nessun EACCES.

> Una blacklist protegge solo ciò che **ricordi** di vietare.
> Corretto: **allowlist / default-deny** — nega tutto, permetti solo il minimo.

<!--
[27:00 → 28:00] DEMO su Docker (stesso container hardened, porta 6663).
Comando: ./tests/test-node.sh app-distroless-hardened conf.
Rilancio lo stesso attacco LFI ma su un file diverso: /etc/come-to-code.conf. Torna ROSSO.
"Guardate il profilo: ho scritto deny su /etc/passwd, /etc/shadow, sul token — ma NON su questo file. Il kernel non lo blocca perché non gli ho mai detto di farlo."
"Questo è il problema strutturale delle blacklist: proteggono solo quello che il difensore ha pensato di vietare.
L'attaccante deve trovare UNA cosa che hai dimenticato; tu devi ricordarti TUTTO."
"In produzione la via corretta è l'opposto: allowlist, default-deny. Nego tutto, permetto esplicitamente solo il minimo che l'app usa davvero.
Qui in demo uso la blacklist perché si legge in 3 righe e si capisce subito il meccanismo sul palco — ma sappiate che in produzione è l'approccio sbagliato."
(Nota: il layer sbagliato per `eval` lo vediamo più avanti, come gancio finale prima di Argus.)
-->

---

## Scrivere l'allowlist: chiedilo (bene) all'AI

- Un profilo AppArmor/Seccomp **allowlist** = ore su documentazione e Stack Overflow
- Oggi puoi farti **abbozzare** il profilo da un'AI, dal comportamento reale dell'app
- Resta **un punto di partenza**: va letto, capito, testato — **mai** incollato alla cieca

> Copiare una risposta Stack Overflow del 2013, 3 upvote, e sperare **non è** una strategia.
> Un profilo sbagliato-ma-sicuro-di-sé è **peggio** di nessun profilo.

<!--
[28:00 → 29:00]
"Scrivere un allowlist AppArmor o un profilo Seccomp buono, a mano, richiede ore: bisogna sapere ESATTAMENTE quali file,
quali syscall, quali path usa davvero la tua app in produzione. Per anni questo ha significato documentazione scarna,
o la classica risposta Stack Overflow del 2013 con tre upvote, copiaincollata pregando che funzioni."
"Oggi puoi usare l'AI per abbozzare un allowlist partendo dal comportamento osservato dell'app — un acceleratore enorme."
"MA — e qui torna il tema di tutto il talk — un profilo generato dall'AI va SEMPRE verificato da un umano prima della produzione.
Un'AI che ti scrive un allowlist sbagliato con grande sicurezza è peggio di nessun allowlist: dà un falso senso di protezione.
Man-in-the-loop, sempre. È esattamente la stessa filosofia che vedremo tra poco con Argus."
-->

---

## Read-only FS e non-root: utili, ma non magici

- `readOnlyRootFilesystem` → blocca le **scritture**. L'LFI è una **lettura**. ❌
- `runAsNonRoot` → utile, ma `/etc/passwd` è world-readable. ❌ per questo caso

> Ogni feature difende da **una** minaccia. Non da *tutte*.

<!--
[29:00 → 30:00]
Punto sottile ma potente: molte 'checkbox di sicurezza' difendono da minacce specifiche.
"Read-only non ferma una lettura. Non-root non ferma la lettura di un file leggibile da tutti.
Non sono inutili — difendono da ALTRO. Ma metterle in check e sentirsi al sicuro è di nuovo la trappola."
-->

---

## Seccomp — filtro delle syscall

```json
// k8s/security/seccomp-go.json (estratto)
{ "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [{ "names": ["memfd_create"], "action": "SCMP_ACT_ERRNO" }] }
```

<span class="tag">DEMO Docker</span>

```bash
./tests/test-go.sh app-go-distroless-hardened
```
```
[ATTACK BLOCKED - HTTP 500]                         🟢
[BLOCKED] memfd_create denied: operation not permitted
```

Difesa al **layer giusto**: AppArmor sui file, Seccomp sulle **syscall**.

<span class="small">Reality check: un allowlist di syscall è fragile — una dipendenza aggiornata può far crashare il container in prod con EPERM. Su K8s: `securityContext.seccompProfile`.</span>

<!--
[30:00 → 32:30] DEMO su Docker (Go hardened, porta 6665, con security_opt seccomp). Ora LIVE.
"Seccomp filtra le SYSCALL a livello di kernel. Il profilo è default-allow (blacklist, per didattica) e nega SOLO
memfd_create. NOTA: non blocco execve — serve al runtime per avviare il container, altrimenti non parte nemmeno."
Comando: ./tests/test-go.sh app-go-distroless-hardened.
"Il primitivo sparisce: EPERM, 'operation not permitted'. Nego la syscall, non il file — è un layer diverso da
AppArmor. Difesa al layer giusto: AppArmor per i FILE, Seccomp per le SYSCALL."
Reality check (onestà): "Ma un allowlist di syscall è fragile: aggiorno una dipendenza, Go introduce una syscall
nuova per la rete, e in produzione il container crasha con EPERM senza una riga di log chiara. Nulla è gratis."
Anticipo (senza svelare tutto): "Notate che Seccomp filtra le SYSCALL, non l'interprete. Tenetelo a mente: torna utile più avanti con eval."
-->

---

## 8. «Sono su un **managed** (GKE). Sono protetto?»

**Shared responsibility:** Google gestisce nodi e control-plane.
Il tuo **bug applicativo (LFI/RCE) resta tuo.** Vive nell'anello *Code*.

- GKE **Autopilot** → baseline forzata (seccomp `RuntimeDefault`, no privileged)... ma non chiude un LFI nel tuo codice
- GKE **Sandbox (gVisor)** → intercetta le syscall in userspace: mitiga *davvero* il fileless
- **Workload Identity** + token a vita breve → riduce il blast radius del furto token

<!--
[32:30 → 35:00] La seconda buzzword smontata.
"'Managed' è forse la parola più fraintesa. Google patcha il kernel, ruota i certificati, protegge l'API server.
Fa un lavoro enorme. Ma NON scrive il tuo codice. L'LFI che avete visto gira identico su GKE.
Il modello si chiama 'shared responsibility': loro l'infrastruttura, TU il workload."
Poi il rovescio positivo: "Il managed però ti DÀ strumenti veri: Autopilot alza il pavimento,
gVisor (GKE Sandbox) mitiga davvero gli attacchi syscall, Workload Identity rende i token effimeri.
Ma li devi ATTIVARE e capire. Non arrivano gratis dalla parola 'managed'."
Ripeti tesi: «Più sicuro» non vuol dire «sicuro».
-->

---

## 9. «Uso la libreria X perché è **più sicura**»
### La supply chain

Non puoi auditare l'**intero albero** delle dipendenze.

**Caso reale: `xz-utils` / CVE-2024-3094 (2024)**
Backdoor inserita a monte, in una libreria di compressione, da un manutentore "fidato".

<!--
[35:00 → 37:30] La terza buzzword.
"'Fastify è più sicuro di Express' — magari è vero, ma è un'opinione, non un threat model.
Il problema vero: la tua app tira dentro centinaia di dipendenze transitive. Non le leggi tutte.
Nel 2024 xz — una libreria di compressione ovunque — è stata backdoorata da un manutentore che si era
costruito fiducia per due anni. Nessuna 'immagine più sicura' ti avrebbe salvato."
Aggancio: "Se non puoi fidarti della catena a monte, ti servono difese a valle, a runtime.
Se la lib è bucata, AppArmor/Seccomp limitano cosa il processo compromesso può fare."
-->

---

## Il filo conduttore

Se **non puoi fidarti** del claim a monte...
...ti servono difese **a valle**, a runtime.

Distroless + AppArmor + Seccomp + RBAC + token effimeri = **anelli**.
Nessuno basta da solo. Insieme = **defense in depth**.

<!--
[37:30 → 38:30]
Sintesi della difesa in profondità. "Non è UNA cosa. È stratificare, sapendo che ogni strato può cedere."
-->

---

## Il gancio che resta aperto: `eval`

<span class="tag">DEMO Docker</span>

```bash
./tests/test-node.sh app-distroless-hardened eval
```
```
[ATTACK SUCCEEDED - HTTP 200]                       🔴
RCE result: 2
```

- AppArmor guarda i **file**, non l'interprete JS → non lo vede
- Seccomp userebbe le **stesse syscall legittime** dell'app (`openat`, `read`) → non si può bloccare senza romperla

# Bug di **Codice**. Si ripara solo allo **shift-left**.

<!--
[38:30 → 39:30] DEMO su Docker (container hardened, porta 6663).
Comando: ./tests/test-node.sh app-distroless-hardened eval. Torna ROSSO, anche col profilo AppArmor attivo.
"Torniamo all'attacco che non abbiamo mai davvero chiuso: eval. AppArmor l'ha lasciato passare perché media l'accesso ai FILE —
non capisce cosa fa l'interprete JavaScript una volta che il processo può leggere quel file."
"E Seccomp? Stessa storia, più sottile: se blocco openat o read per fermare un eval-che-legge-un-token, rompo anche i requisiti
legittimi dell'app — Node deve poter aprire e leggere file per funzionare. Non posso distinguere a livello di syscall
un read 'legittimo' da uno 'malizioso': sono LA STESSA syscall."
"Quindi: distroless non lo tocca, AppArmor non lo vede, Seccomp non può bloccarlo senza rompere l'app.
Nessun layer RUNTIME risolve eval, perché eval non è un problema di runtime: è un bug scritto nel CODICE.
E un bug di codice si ripara PRIMA che il codice giri: shift-left. Torniamo ad Argus."
-->

---

## 10. Trovarli **prima** della produzione
### Security review aumentata dall'AI — Argus

Come trovi un LFI, un `eval`, un memfd nel codice *prima* del deploy? **Static analysis.**

- Semgrep · CodeQL · gosec (Go) · Bandit (Python) · ESLint security · Gitleaks (secrets) · OSV-Scanner (deps)
- **Argus** orchestra Semgrep + Gitleaks + OSV-Scanner + ragionamento AI — **sempre un umano nel loop**
- Assist al talk di **Davide Imola** · Tool CLI **gotrova**: `go install github.com/gafreax/gotrova/cmd/gotrova@latest`

<!--
[39:30 → 41:30]
Chiudi il cerchio: "Tutti i bug di oggi sono nel CODICE — command injection, LFI, eval, persino il fileless Go.
Il posto migliore per fermarli è la review, PRIMA del deploy, non a runtime."
"Il mondo static-analysis è pieno di strumenti maturi: Semgrep per pattern semantici cross-linguaggio, CodeQL di GitHub
per query strutturali profonde, gosec se scrivete Go, Bandit se scrivete Python, i plugin di sicurezza di ESLint per JS/TS,
Gitleaks per beccare segreti finiti nel repo, OSV-Scanner per le vulnerabilità nelle dipendenze."
"Argus — il progetto che presento assieme a Davide Imola — orchestra diversi di questi tool (Semgrep, Gitleaks, OSV-Scanner)
e ci aggiunge un livello di ragionamento AI per correlare e prioritizzare i risultati. Ma — esattamente come per l'allowlist
AppArmor di prima — SEMPRE con un umano nel loop: l'AI accelera la review, non la sostituisce."
"Noi umani ci perdiamo un eval in mezzo a 10.000 righe. L'AI aiuta a trovarlo. Ma la decisione finale resta umana."
Assist a Davide Imola (coordina col suo talk).
-->

---

## 11. La tesi, di nuovo

# «Più sicuro» **non vuol dire** «sicuro».

- Distroless, "managed", "questa lib è sicura" = **punti di partenza**
- La sicurezza è **andare a fondo**: threat model, verifica, stratificazione
- Ogni difesa protegge da *una* minaccia. Serve la **catena**.

<!--
[41:30 → 43:00] Chiusura forte. Rallenta, guarda il pubblico.
"Se portate a casa una frase sola: 'più sicuro' è un comparativo, non uno stato.
Ogni volta che leggete 'secure by default', 'zero trust', 'hardened', 'managed' — chiedetevi: contro COSA?
Poi andate a fondo. Le buzzword iniziano il ragionamento. Non lo finiscono."
-->

---

## Riferimenti

- **NIST SP 800-190** — Application Container Security Guide
- **Kubernetes** — Overview of Cloud Native Security (le 4C)
- **OWASP** — Path Traversal · Top 10 · Docker/K8s Cheat Sheet
- **GoogleContainerTools/distroless**
- **GKE** — Shared responsibility · Autopilot · Sandbox (gVisor) · Workload Identity
- **CVE-2024-3094** (xz backdoor)
- Static analysis: **Semgrep** · **CodeQL** · **gosec** · **Bandit** · **Gitleaks** · **OSV-Scanner**
- Repo demo + **gotrova**: `github.com/gafreax/gotrova`

<!--
[43:00 → 43:30] Lascia questa slide su durante le domande.
-->

---

## Grazie!
# Domande?

<span class="small">Le slide e il codice della demo sono nel repo.</span>

<!--
[43:30 → 45:00+] Q&A.
Ripassa prima le "domande scomode" in docs/04-review-opus.md (sez. 6):
Distroless inutile? / GKE mi protegge? / Autopilot? / gVisor? / perché non un WAF? /
AppArmor su managed? / il token è reale? / read-only non basta? / non-root?
-->
