---
marp: true
theme: caw
size: 16:9
paginate: true
html: true
---

<!--
SPEAKER NOTES — LEGENDA
- Ogni slide ha una nota (questo blocco HTML) con: cosa dire, cosa fare, timing.
- DEMO = esecuzione live SOLO su Docker (docker-compose). Kubernetes viene NOMINATO/MOSTRATO, non eseguito.
- CODE = commento al codice live (non live-coding: il codice è già a schermo).
- Tesi ricorrente da ripetere 3-4 volte: «Più sicuro» non vuol dire «sicuro».
- Budget totale ~45 min. I minuti indicati sono cumulativi indicativi.
- REGOLA: tieni pronto un video di backup di ogni DEMO. Se si rompe, mandi il video e vai avanti.
- STRUTTURA v4: Apertura → ATTO 1..4 (ognuno chiuso da uno SCOREBOARD progressivo) → Le altre buzzword → Chiusura (scoreboard finale).
-->

<!-- _class: lead -->
<!-- _header: '' -->

# Container at War
## Distroless, hardening e il mito del «più sicuro»
<br>

<span class="small">Come to Code 2026 · Pignola · Gabriele Fontana</span>

<!--
[0:00 → 0:30] Apertura — SOLO ringraziamenti.
Grazie a Come to Code + a Ivan (MC del track) + al pubblico, poi pianta la parola "sicuro / più sicuro". NIENTE bio qui: il "chi sono" è tutto sulla slide 2.
Testo completo: frasi-speaker.md §1 (Slide 1).
-->

---

<!-- _header: '' -->

## Chi sono

<div class="cols">
<div>

# Gabriele Fontana
**Senior Software Engineer** · redcarbon.ai

</div>
<div>

<span class="small">
GitHub · <code>github.com/gafreax</code><br>
LinkedIn · <code>in/gabrielefontana</code><br>
gafreax@gmail.com
</span>

</div>
</div>

<!--
[0:30 → 1:45] Chi sono — QUI vive il racconto personale, prenditi il tempo (~60-75s). NON leggere i bullet.
Segui frasi-speaker.md §1 (Slide 2): linguaggi + autoironia sui bug → storia Linux (Red Hat 7.2 → Mandrake → OpenSUSE 8 → Slackware → battuta Ivan → "sono vecchio") → aggancio a Davide/Argus + comfort-zone.
La slide è già compilata (ruolo, azienda, contatti); i bullet sono solo appoggio visivo.
-->

---

<!-- _header: '' -->

## La tesi, in una frase

<span class="statement">«Più sicuro» <em>non vuol dire</em> «sicuro».</span>

Le buzzword sono un **punto di partenza**, non un threat model.

<!--
[1:45 → 2:30] Il patto col pubblico. (Testo: frasi-speaker.md §1 — Slide 3.)
Dì: "Oggi useremo Distroless come caso-studio, ma il messaggio vale per tre frasi che sentiamo ogni giorno:
1) 'È distroless, quindi è sicuro'
2) 'Sono su un managed / GKE, quindi sono protetto'
3) 'Uso questa libreria perché è più sicura'.
Le smontiamo una a una. Non per dire che sono inutili — ma che sono l'INIZIO del ragionamento, non la fine."
Anticipa il formato: "Vedremo codice vero e qualche attacco eseguito dal vivo. Su Docker, per tenere le cose semplici — ma tutto questo gira identico su Kubernetes."
-->

---

<!-- _header: '' -->

## Il mito Distroless

Immagini *distroless* = solo la tua app e le sue dipendenze runtime.

- Niente shell (`/bin/sh`)
- Niente package manager (`apt`, `apk`)
- Niente tool (`curl`, `wget`, `ls`)

<!--
[2:30 → 3:00]
Spiega cos'è distroless in modo semplice. "Prendi Ubuntu, togli tutto quello che non serve a far girare la tua app. Resta quasi solo il runtime."
Fai l'esempio pratico: "Provate a fare `kubectl exec` in un pod distroless: non c'è la shell, non entrate. All'inizio spiazza."
-->

---

<!-- _header: '' -->

## Perché distroless è nata (ed è un bene)

- Superficie d'attacco ridotta
- **Meno CVE** (meno pacchetti = meno vulnerabilità note)
- Immagine più piccola, deploy più veloci, meno da mantenere

> Distroless è **necessario ma non sufficiente**.

<!--
[3:00 → 3:30] importante — onestà intellettuale.
NON vogliamo che il pubblico esca pensando "distroless è inutile". È il contrario.
Dì chiaramente: "Se non state usando immagini minimali, iniziate. Fanno bene davvero.
Il punto del talk è un altro: risolvono UN problema, non IL problema."
Ripeti il claim di marketing: "Il messaggio implicito però è: 'minimale = sicuro'. È lì che caschiamo."
-->

---

<!-- _header: '' -->

## Come nasce un'immagine distroless
### Multi-stage: costruisci con tutto, spedisci quasi niente

<div class="cols">
<div>

**Classica** — un solo stage
```dockerfile
FROM node:24
COPY . .
RUN npm install
CMD ["node","server.js"]
```
Spedisci tutta la Debian: bash, apt, npm.

</div>
<div>

**Distroless** — due stage
```dockerfile
# 1. build (immagine piena)
FROM node:24 AS build
RUN npm install
# 2. runtime (app + node)
FROM distroless/nodejs24
COPY --from=build /app /app
CMD ["server.js"]
```

</div>
</div>

<span class="small">Go: stessa idea — stage 1 <code>golang:1.27</code> compila il binario statico, stage 2 lo copia in <code>distroless/static</code>. · Le ricostruisci con <code>docker compose up --build -d &lt;servizio&gt;</code></span>

<!--
[3:30 → 4:00] il "gancio" su come sono fatte le immagini — ORA dopo i vantaggi: cos'è → perché è un bene → come si costruisce.
"Abbiamo detto cos'è e perché conviene. Ma come nasce, in pratica? Il trucco si chiama multi-stage build.
Stage 1: parto da un'immagine piena — Node completo, con npm — e ci costruisco l'app.
Stage 2: parto da distroless e ci copio DENTRO solo il risultato. Il compilatore, npm, la shell restano
nello stage 1 e non arrivano mai nell'immagine finale. Ecco perché nel distroless non c'è /bin/sh:
non l'ho 'tolto', semplicemente non l'ho mai copiato."
Go è identico: stage 1 golang compila un binario statico, stage 2 lo copia in distroless/static — l'immagine finale è quasi solo quel file.
Come le ricostruisco per la demo: docker compose up --build -d <nome-servizio> (compose trova il servizio nel compose file, ognuno ha il suo build: e Dockerfile). Tutti insieme: docker compose up --build -d.
-->

---

<!-- _header: '' -->

## La domanda del talk

Se tolgo la shell...

<span class="statement">...ho tolto l'<em>attaccante</em>?</span>

Verifichiamo con il codice!

<!--
[4:00 → 4:30] Ponte verso la prima demo. Tono da "mettiamo alla prova il claim".
-->

---

<!-- _class: divider -->
<!-- header: 'ATTO 1 — La falsa vittoria' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">ATTO 1</div>

# La falsa vittoria
<div class="bar"></div>

<p>Un attacco classico, un claim che sembra reggere. Poi lo smontiamo.</p>

<!--
Transizione d'ingresso all'ATTO 1. Tono deciso, da "mettiamo alla prova il claim" a "vi mostro un attacco vero".
-->

---

## Command Injection

<pre class="code-hl"><code class="language-js"><span class="line hljs-comment">// src/demo-node/server.js — endpoint /attack/command-injection</span>
<span class="line hljs-comment">// fastify.get('/attack/command-injection', (req, reply) => {</span>
<span class="line">  <span class="hljs-keyword">const</span> ip = req.<span class="hljs-property">query</span>.<span class="hljs-property">ip</span> || <span class="hljs-string">&#x27;8.8.8.8&#x27;</span>;</span>
<span class="line vuln"><span class="hljs-title function_">exec</span>(<span class="hljs-string">`ping -c 1 <span class="hljs-subst">${ip}</span>`</span>, <span class="hljs-function">(<span class="hljs-params">err, stdout</span>) =&gt;</span> {</span>
<span class="line"><span class="vuln-arrow">← exec = /bin/sh -c</span></span>
<span class="line">    <span class="hljs-keyword">return</span> reply.<span class="hljs-title function_">send</span>(err ? <span class="hljs-string">`[FAILED] <span class="hljs-subst">${err.message}</span>`</span> : stdout);</span>
<span class="line">  });</span>
<span class="line">});</span></code></pre>


<!--
[4:30 → 6:00] CODE.
Commenta: "Classico bug da manuale. Concateno input utente dentro un comando. `exec` di Node NON esegue il binario direttamente: apre `/bin/sh -c '...'`. Tenete a mente questo dettaglio."
Payload che mostreremo: ip = 8.8.8.8;id  → su immagine classica esegue anche `id` (uid=0(root)).
-->

---

## Demo — immagine classica vs distroless

<span class="tag demo">DEMO · Docker</span>

<div class="term" data-title="app-classic · :6661">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-classic · :6661</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">curl -sG ".../attack/command-injection" --data-urlencode "ip=8.8.8.8;id"</span>HTTP 200 — ping <span class="hi">+ id</span> eseguiti → <span class="fail">uid=0(root)</span></pre>
</div>

<div class="term" data-title="app-distroless · :6662">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless · :6662</span><span class="pill green">BLOCCATO</span></div>
<pre class="term-out"><span class="cmd">curl -sG ".../attack/command-injection" --data-urlencode "ip=8.8.8.8;id"</span>HTTP 500 — <span class="ok">[FAILED] spawn /bin/sh ENOENT</span></pre>
</div>

<span class="small">Scorciatoia per le demo successive: <code>./tests/test-node.sh app-classic cmdi</code> — è lo stesso <code>curl</code>, colorato in base allo status HTTP.</span>

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

- Distroless ha rotto **la kill-chain classica** (spawn di shell)
- Ma la **vulnerabilità è ancora lì**
- È fallita *l'exploitation*, non è sparito il bug

<span class="statement">«Più sicuro» <em>≠</em> «sicuro»</span>

<!--
[8:00 → 9:00] Il primo ribaltone concettuale.
Dì: "Ho scelto apposta un attacco che ha BISOGNO della shell. Ho truccato il match.
Distroless ha fermato quel vettore. Non ha reso il codice corretto.
E se trovo un attacco che NON ha bisogno della shell?"
-->

---

<!-- _header: '' -->

## Scoreboard — dopo l'ATTO 1

<table class="scoreboard">
<thead><tr><th></th><th>classic<br>:6661</th><th>distroless<br>:6662</th><th>hardened<br>:6663</th><th>go-distroless<br>:6664</th><th>go-hardened<br>:6665</th></tr></thead>
<tbody>
<tr><td>cmdi</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>passwd</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>token</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>conf</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>eval</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>fileless</td><td class="na">n/a</td><td class="na">n/a</td><td class="na">n/a</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td></tr>
</tbody>
</table>

<div class="legend"><span class="lk"><span class="sw red"></span>riuscito</span><span class="lk"><span class="sw green"></span>bloccato</span><span class="lk"><span class="sw grey"></span>non ancora testato</span><span class="lk">n/a — attacco non applicabile a quel container</span></div>

<!--
Punto di controllo visivo dopo l'ATTO 1. Non serve dire molto: lasciala parlare.
"Una riga verde, tutto il resto grigio: non l'abbiamo ancora testato. Andiamo avanti."
-->

---

<!-- _class: divider -->
<!-- header: 'ATTO 2 — L'illusione cade' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">ATTO 2</div>

# L'illusione cade
<div class="bar"></div>

<p>Un attacco che non ha mai avuto bisogno di una shell.</p>

<!--
Frase-ponte: "E qui la maggior parte delle presentazioni finirebbe. 'Ho tolto la shell, ho vinto, buonasera.' Tenetevi forte: vi ho appena mentito, e ve lo dimostro. Cambiamo attacco: uno che di shell non ne ha bisogno per niente."
-->

---

## La sicurezza è una **catena**
### Le 4C della Cloud Native Security

**Code** → **Container** → **Cluster** → **Cloud**

Distroless lavora su **un solo anello** (Container).
Il bug della demo vive nell'anello **Code**.

<span class="statement">La forza di una catena è quella del suo <em>anello più debole</em>.</span>

<span class="small">Le 4C: Kubernetes — Overview of Cloud Native Security · La catena: come me l'ha insegnata una persona a cui devo molto</span>

<!--
[9:00 → 11:00]
Le 4C sono un modello ufficiale K8s: citalo, ti dà autorevolezza.
"Ogni anello ha le sue difese. Distroless è una difesa dell'anello Container.
Il mio bug — la command injection, l'LFI che vedremo — vive nell'anello Code.
Nessuna quantità di hardening del Container ripara un anello che sta più in alto."
Cita OWASP Top 10: injection, path traversal, deserializzazione insicura — sono tutti bug di 'Code'.

L'ANELLO PIÙ DEBOLE:
"Questo concetto — la sicurezza di una catena è quella del suo anello più debole — me l'ha insegnato
una persona a cui devo molto. Ed è esattamente il punto di stasera: puoi blindare un anello quanto vuoi,
ma l'attaccante attacca quello che hai lasciato debole."
Il filo si richiude in chiusura con la difesa in profondità.
-->

---

## Local File Inclusion / Path Traversal

<pre class="code-hl"><code class="language-js"><span class="line hljs-comment">// endpoint /attack/path-traversal</span>
<span class="line hljs-comment">// fastify.get('/attack/path-traversal', async (req, reply) => {</span>
<span class="line vuln">  <span class="hljs-keyword">return</span> reply.<span class="hljs-title function_">send</span>(fs.<span class="hljs-title function_">readFileSync</span>(req.<span class="hljs-property">query</span>.<span class="hljs-property">file</span>, <span class="hljs-string">&#x27;utf8&#x27;</span>));</span>
<span class="line"><span class="vuln-arrow">← nessuna validazione</span></span>
<span class="line">});</span></code></pre>

<span class="tag code">CODE</span> Node **non ha bisogno di bash** per leggere un file.

<!--
[11:00 → 12:30] CODE.
"Qui non c'è nessuna shell coinvolta. `fs.readFileSync` è codice Node nativo.
L'attaccante controlla il path. Distroless non può fare NULLA: sto usando una funzione legittima del runtime."
Prepara il pubblico all'easter egg.
-->

---

## Demo — LFI: `/etc/passwd` **e** il token del cluster

<span class="tag demo">DEMO · Docker</span> Un solo passaggio, due letture

<div class="term" data-title="app-distroless · :6662">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless · :6662</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-node.sh app-distroless passwd token</span><span class="fail">[passwd] ATTACK SUCCEEDED - HTTP 200</span>
root:x:0:0:root:/root:/bin/bash  ...
<span class="hi">darth_vader:x:66:66:Sith Lord:/death_star:/bin/force_choke</span>
<span class="fail">[token]  ATTACK SUCCEEDED - HTTP 200</span>
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6...</pre>
</div>

Service Account Token → **movimento laterale nel cluster**. Nessuna shell. Solo `fs.readFileSync`.

<span class="small">(Token FINTO montato per la demo — meccanismo reale, valore innocuo.)</span>

<!--
[12:30 → 15:30] DEMO su Docker (distroless, :6662) — UN SOLO momento-demo, due letture di fila.
Comando: ./tests/test-node.sh app-distroless passwd token.
1) passwd: lascia leggere l'easter egg. Battuta: "sul mio server gira anche Darth Vader, shell /bin/force_choke."
   Poi: "Ok, /etc/passwd, chi se ne frega. Ora alziamo la posta." — e SUBITO il token, senza cambiare slide.
2) token: mostra il JWT, decodificalo su jwt.io (usa il token FINTO valido, non uno malformato).
   Blast radius: "con un SA token permissivo parlo con l'API server; da un bug in UNA app mi muovo sul namespace."
   DILLO: "Il token è finto, ma il meccanismo è reale al 100%."
Stacci dentro con calma: è il cuore dell'ATTO 2.
-->

---

## «E su Kubernetes?»

<span class="tag k8s">K8s · mostrato, non eseguito</span>

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

## RCE **senza** shell
### Il runtime *è* la shell

<pre class="code-hl"><code class="language-js"><span class="line hljs-comment">// endpoint /attack/eval-rce</span>
<span class="line hljs-comment">// fastify.get('/attack/eval-rce', (req, reply) => {</span>
<span class="line vuln">  <span class="hljs-keyword">const</span> result = <span class="hljs-title function_">eval</span>(req.<span class="hljs-property">query</span>.<span class="hljs-property">code</span>);</span>
<span class="line"><span class="vuln-arrow">← esecuzione arbitraria JS</span></span>
<span class="line">  <span class="hljs-keyword">return</span> reply.<span class="hljs-title function_">send</span>(<span class="hljs-string">`RCE result: <span class="hljs-subst">${result}</span>`</span>);</span>
<span class="line">});</span></code></pre>

<span class="tag code">CODE</span> Non mi serve `/bin/sh`: mi serve il tuo **interprete**.

<!--
[16:30 → 18:00] CODE.
"L'ossessione per 'togliere la shell' parte da un presupposto: che l'attaccante voglia UNA shell.
Ma se la tua app è un interprete — Node, Python, Ruby — l'interprete È già una shell.
`eval` esegue qualsiasi JS: posso fare require('fs'), require('child_process')... dentro il processo Node,
senza mai toccare /bin/sh."
-->

---

## Demo — esecuzione di codice arbitrario

<span class="tag demo">DEMO · Docker</span>

<div class="term" data-title="app-distroless · :6662">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless · :6662</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-node.sh app-distroless eval</span><span class="fail">[ATTACK SUCCEEDED - HTTP 200]</span>
RCE result: 2</pre>
</div>

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

<!-- _header: '' -->

## Scoreboard — dopo l'ATTO 2

<table class="scoreboard">
<thead><tr><th></th><th>classic<br>:6661</th><th>distroless<br>:6662</th><th>hardened<br>:6663</th><th>go-distroless<br>:6664</th><th>go-hardened<br>:6665</th></tr></thead>
<tbody>
<tr><td>cmdi</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>passwd</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>token</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>conf</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>eval</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>fileless</td><td class="na">n/a</td><td class="na">n/a</td><td class="na">n/a</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td></tr>
</tbody>
</table>

<div class="legend"><span class="lk"><span class="sw red"></span>riuscito</span><span class="lk"><span class="sw green"></span>bloccato</span><span class="lk"><span class="sw grey"></span>non ancora testato</span><span class="lk">n/a — attacco non applicabile a quel container</span></div>

<!--
"Guardate la colonna distroless: quattro rosse su cinque. Una sola cosa l'ha fermata: la shell. Il resto è ancora tutto aperto.
Fin qui vi ho solo depressi. Ora la buona notizia: le difese esistono. Ma non sono dove pensate — non sono nell'immagine, sono nel kernel."
-->

---

<!-- _class: divider -->
<!-- header: 'ATTO 3 — Hardening' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">ATTO 3</div>

# Hardening
<div class="bar"></div>

<p>La difesa vera non vive nell'immagine. Vive nel kernel.</p>

<!--
Transizione verso la parte positiva del talk. Rallenta un po', cambia energia: da "vi ho spaventato" a "vi do gli strumenti".
-->

---

## Un container **non ha** un kernel

AppArmor e Seccomp sono moduli del **kernel dell'host** (il nodo).
L'immagine distroless non li conosce: è il **nodo** che intercetta il processo.

<!--
[19:30 → 20:30]
Concetto chiave spesso frainteso: "Il container condivide il kernel dell'host.
Non c'è un kernel 'dentro' l'immagine. Quindi le difese kernel — AppArmor, Seccomp —
vivono sul NODO, non nell'immagine. Ecco perché distroless da solo non può offrirle."
-->

---

## AppArmor — cos'è
### MAC: *cosa* un processo può toccare

- **Mandatory Access Control**: una policy che il processo **non può aggirare**
- Filtra **file, rete, capabilities** — non le syscall
- Regola tipica: *"Node può leggere `/app`, non `/etc` né `/var/run/secrets`"*
- Vive nel **kernel dell'host**, applicato per-processo via **profilo**

> Piano d'azione: i **file**. (Le syscall sono un altro layer → Seccomp.)

<!--
[20:30 → 21:00] Slide-concetto (nuova). Introduci AppArmor PRIMA della demo, come con distroless.
"AppArmor è un MAC: decido cosa un programma può fare sui FILE. Non guarda le syscall, guarda i path.
È il kernel dell'host a farlo rispettare — l'app non può disattivarlo." ~30s, poi vai alla demo.
-->

---

## AppArmor — controllo sull'accesso ai file

```
# k8s/security/apparmor-node-profile (estratto)
deny /etc/passwd mrw,
deny /etc/shadow mrw,
deny /var/run/secrets/kubernetes.io/serviceaccount/** mrw,
```

<span class="tag demo">DEMO · Docker</span> Ritento l'LFI sul container *hardened*

<div class="term" data-title="app-distroless-hardened · :6663">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless-hardened · :6663</span><span class="pill green">BLOCCATO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-node.sh app-distroless-hardened passwd token</span><span class="ok">[ATTACK BLOCKED - HTTP 500]</span>
Read error: EACCES</pre>
</div>

<span class="small">Nota onesta: qui uso una blacklist per didattica. In produzione → allowlist (vedi slide dopo).</span>

<!--
[21:00 → 22:30] DEMO su Docker (container app-distroless-hardened, porta 6663, con security_opt apparmor).
Comando: ./tests/test-node.sh app-distroless-hardened passwd token — rilancia le stesse due LFI di prima, ora contro 6663.
Entrambe tornano VERDI: "Read error: EACCES". "Il kernel dell'host ha intercettato la readFileSync di Node PRIMA che leggesse il file."
Onestà: "Sto usando una blacklist — 'nega questi file'. È fragile: dimentichi un file e sei fregato. Tra un attimo vi mostro esattamente cosa succede quando dimentichi."
K8s: "Su Kubernetes stesso profilo, via securityContext.appArmorProfile (da 1.30)." — mostra riga, non eseguire.

ZERO TRUST (se qualcuno lo chiede / se vuoi agganciarlo): questo è il PRINCIPIO del least privilege / default-deny,
lo stesso che sta ALLA BASE dello zero trust. Dì "è lo stesso principio dello zero trust", NON "AppArmor è zero trust":
lo Zero Trust (NIST SP 800-207) è un'architettura più ampia, incentrata su identità e rete ("never trust, always verify",
microsegmentazione, auth per-richiesta), non sul MAC dei file. Un esperto ti riprenderebbe se lo chiami "zero trust" e basta.
-->

---

## AppArmor — il buco della blacklist

<span class="tag demo">DEMO · Docker</span>

<div class="term" data-title="app-distroless-hardened · :6663">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless-hardened · :6663</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-node.sh app-distroless-hardened conf</span><span class="fail">[ATTACK SUCCEEDED - HTTP 200]</span></pre>
</div>

Stesso LFI, file diverso: `/etc/come-to-code.conf`.
La blacklist **non lo conosce** → nessun `deny`, nessun EACCES.

> Una blacklist protegge solo ciò che **ricordi** di vietare.
> Corretto: **allowlist / default-deny** — nega tutto, permetti solo il minimo.

<!--
[22:30 → 23:30] DEMO su Docker (stesso container hardened, porta 6663).
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

<span class="statement">Un profilo sbagliato-ma-sicuro-di-sé è <em>peggio</em> di nessun profilo.</span>

<span class="small">Ho impacchettato questo flusso (osserva → genera → rivedi) in una skill open: <code>npx skills add gafreax/skill-seccomp-apparmor-profiler</code></span>

<!--
[23:30 → 24:30]
"Scrivere un allowlist AppArmor o un profilo Seccomp buono, a mano, richiede ore: bisogna sapere ESATTAMENTE quali file,
quali syscall, quali path usa davvero la tua app in produzione. Per anni questo ha significato documentazione scarna,
o la classica risposta Stack Overflow del 2013 con tre upvote, copiaincollata pregando che funzionasse."
"Oggi puoi usare l'AI per abbozzare un allowlist partendo dal comportamento osservato dell'app — un acceleratore enorme."
"MA — e qui torna il tema di tutto il talk — un profilo generato dall'AI va SEMPRE verificato da un umano prima della produzione.
Un'AI che ti scrive un allowlist sbagliato con grande sicurezza è peggio di nessun allowlist: dà un falso senso di protezione.
Man-in-the-loop, sempre. È esattamente la stessa filosofia che vedremo tra poco con Argus."
-->

---

## Read-only FS e non-root: utili, ma non magici

- `readOnlyRootFilesystem` → blocca le **scritture**. L'LFI è una **lettura**.
- `runAsNonRoot` → utile, ma `/etc/passwd` è world-readable: non basta per questo caso.

> Ogni feature difende da **una** minaccia. Non da *tutte*.

<!--
[24:30 → 25:15]
[FIRST CUT CANDIDATE se sei sopra tempo: questa slide è la prima da tagliare — il punto "ogni feature difende da una minaccia" è già passato con blacklist/allowlist, qui è solo un secondo esempio.]
Punto sottile ma potente: molte 'checkbox di sicurezza' difendono da minacce specifiche.
"Read-only non ferma una lettura. Non-root non ferma la lettura di un file leggibile da tutti.
Non sono inutili — difendono da ALTRO. Ma metterle in check e sentirsi al sicuro è di nuovo la trappola."
-->

---

## Seccomp — cos'è
### Filtra *cosa* un processo chiede al kernel

- **SEC**ure **COMP**uting: allow/deny list delle **system call**
- Opera **più in basso** di AppArmor: non i file, ma le *richieste al kernel* (`memfd_create`, `ptrace`, `mount`…)
- Applicato dal runtime: Docker `security_opt`, k8s `seccompProfile`
- ⚠️ Mai negare `execve`: serve al runtime per **avviare** il container

> **AppArmor guarda i file. Seccomp guarda le syscall.** Layer diversi, complementari.

<!--
[25:15 → 25:45] Slide-concetto (nuova). "Seccomp filtra le SYSCALL — le richieste che il processo fa al kernel.
È un gradino sotto AppArmor: non 'quali file', ma 'quali chiamate di sistema'. Regola d'oro: non toccare execve."
~30s, poi mostra il profilo.
-->

---

## Seccomp — filtro delle syscall

```json
// k8s/security/seccomp-go.json (estratto)
{ "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [{ "names": ["memfd_create"], "action": "SCMP_ACT_ERRNO" }] }
```

Difesa al **layer giusto**: AppArmor sui file, Seccomp sulle **syscall**.
<span class="small">Anticipiamo la demo live nell'ATTO 4 — stesso meccanismo, container Go.</span>

<span class="small">Reality check: un allowlist di syscall è fragile — una dipendenza aggiornata può far crashare il container in prod con EPERM. Su K8s: `securityContext.seccompProfile`.</span>

<!--
[25:45 → 26:15] Qui mostriamo SOLO il profilo (CODE) — la demo live di Seccomp è nell'ATTO 4 con il container Go, per non anticipare il colpo di scena del fileless.
"Seccomp filtra le SYSCALL a livello di kernel. Il profilo è default-allow (blacklist, per didattica). NOTA: non blocco execve — serve al runtime per avviare il container, altrimenti non parte nemmeno."
"Difesa al layer giusto: AppArmor per i FILE, Seccomp per le SYSCALL."
Reality check (onestà): "Ma un allowlist di syscall è fragile: aggiorno una dipendenza, Go introduce una syscall
nuova per la rete, e in produzione il container crasha con EPERM senza una riga di log chiara. Nulla è gratis."
Anticipo (senza svelare tutto): "Notate che Seccomp filtra le SYSCALL, non l'interprete. Tenetelo a mente: torna utile più avanti con eval."
-->

---

<!-- _header: '' -->

## Scoreboard — dopo l'ATTO 3

<table class="scoreboard">
<thead><tr><th></th><th>classic<br>:6661</th><th>distroless<br>:6662</th><th>hardened<br>:6663</th><th>go-distroless<br>:6664</th><th>go-hardened<br>:6665</th></tr></thead>
<tbody>
<tr><td>cmdi</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>passwd</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>token</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>conf</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>eval</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>fileless</td><td class="na">n/a</td><td class="na">n/a</td><td class="na">n/a</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td></tr>
</tbody>
</table>

<div class="legend"><span class="lk"><span class="sw red"></span>riuscito</span><span class="lk"><span class="sw green"></span>bloccato</span><span class="lk"><span class="sw grey"></span>non ancora testato</span><span class="lk">n/a — attacco non applicabile a quel container</span></div>

<!--
"La colonna hardened si sta riempendo di verde — ma guardate: `conf` è rosso, ed `eval` non l'abbiamo nemmeno ritestato qui apposta. Ci arriviamo, ma prima cambiamo completamente bersaglio."
-->

---

<!-- _class: divider -->
<!-- header: 'ATTO 4 — Cambio di fase' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">ATTO 4</div>

# Cambio di fase
<div class="bar"></div>

<p>Dai primi tre round — come si entra — a cosa succede dopo.</p>

<!--
Transizione: "Distroless con Node l'abbiamo visto. Ma io compilo un binario Go statico, minimale — cosa vuoi attaccare? Guardate."
-->

---

## Non è più "come entro". È "cosa faccio dopo"

- ATTO 1-3: **initial access / exploitation** — un bug nel codice (cmdi, LFI, `eval`) dà l'esecuzione.
- ATTO 4: qui **non c'è un bug** da sfruttare. L'attaccante è **già dentro** — ci è arrivato con l'`eval` di prima o con una **dipendenza compromessa** (xz): codice ostile che gira *dentro* il tuo processo. Ora la domanda è: **cosa fa senza farsi vedere?**
- Siamo in **post-exploitation / defense evasion**: caricare un payload senza toccare il disco. MITRE ATT&CK `T1620` — *Reflective Code Loading*.

<span class="statement">Seccomp non impedisce <em>l'ingresso</em>. Impedisce <em>la mossa successiva</em>.</span>

<!--
[26:30 → 27:45] Slide di framing NUOVA — obbligatoria prima del codice Go, altrimenti la demo sembra scollegata dal resto.
Di': "Fin qui vi ho mostrato bug che aprono la porta. Ora cambio completamente registro: nel codice che segue non c'è NESSUNA vulnerabilità da sfruttare. Sto assumendo che l'attaccante sia GIÀ dentro."

RISPOSTA PRONTA alla domanda "ma chi ha eseguito quel codice Go? Se l'attaccante esegue già codice, hai già perso":
"Giusta obiezione, e la risposta è che l'esecuzione l'ha già ottenuta PRIMA — esattamente con l'eval che avete visto due slide fa, oppure con una dipendenza compromessa come xz (lo vediamo tra poco). Il punto non è impedire l'esecuzione iniziale — quella è già persa, ed è un problema di CODICE che si ripara a monte (shift-left, Argus). Il punto è: una volta che l'attaccante è dentro, cosa può fare per RESTARE nascosto e muoversi senza lasciare tracce su disco? È lì che Seccomp entra in gioco. Non è la prima linea di difesa: è la difesa in profondità, DOPO che la prima linea ha ceduto."
Se il tempo stringe, questa risposta può essere abbreviata, ma va sempre data — è la domanda più prevedibile della sessione Q&A e la slide che la disinnesca in anticipo.
-->

---

<!-- _header: '' -->

## L'immagine più minimale che esista
### Go statico: due stage, e resta *solo il binario*

<div class="cols">
<div>

```dockerfile
# 1. build: toolchain completa
FROM golang:1.27 AS build
RUN CGO_ENABLED=0 \
    go build -o /demo-go .
# 2. runtime: solo il binario
FROM distroless/static
COPY --from=build /demo-go /
ENTRYPOINT ["/demo-go"]
```

</div>
<div>

L'immagine finale è **un unico file statico**:

- niente shell, niente libc
- niente package manager
- niente interprete (nessun `eval`)

<span class="small"><code>CGO_ENABLED=0</code> = zero librerie condivise: tutto dentro il binario.</span>

</div>
</div>

<span class="statement">Se «minimale = sicuro» fosse vero, sarebbe vero <em>qui</em>.</span>

<!--
[27:45 → 28:45] premessa alla demo fileless.
"Questo è il caso estremo. Node aveva un runtime, un interprete, l'eval. Qui compilo un binario Go statico:
CGO_ENABLED=0 vuol dire zero librerie condivise, tutto dentro un file. Lo metto in distroless/static e
l'immagine finale è QUASI SOLO quel binario. Niente shell, niente libc, niente interprete. È il container
più minimale che si possa spedire — la versione più forte di 'non c'è niente da attaccare'.
Se il claim 'minimale = sicuro' regge da qualche parte, deve reggere qui. Guardate cosa succede."
Transizione naturale alla slide dopo: eppure può ancora chiamare memfd_create.
-->

---

## Fileless: eseguire senza toccare il disco
### `memfd_create` in Go

<pre class="code-hl"><code class="language-go"><span class="line hljs-comment">// memfd_create: file anonimo, vive SOLO in RAM (mai su disco)</span>
<span class="line vuln">fd, _ := <span class="hljs-title function_">unix.MemfdCreate</span>(<span class="hljs-string">&quot;demo&quot;</span>, <span class="hljs-property">unix.MFD_CLOEXEC</span>)</span>
<span class="line"><span class="vuln-arrow">← nessun file su disco</span></span></code></pre>

Nessun file su disco. Read-only FS inutile qui. AppArmor guarda i **file**, non le syscall: non lo vede.

<span class="small">Questo endpoint è una <b>controfigura</b>: nella realtà a chiamare <code>memfd_create</code> è il codice dell'attaccante (arrivato via dipendenza compromessa), non un endpoint. Qui è dietro un <code>curl</code> solo per innescarlo dal vivo.</span>

<!--
[28:45 → 30:00] CODE + ponte alla demo.
"Un'altra buzzword: 'binario statico minimale, non c'è niente da attaccare'. Guardiamo."
"memfd_create crea un file ANONIMO che vive solo in RAM: non tocca mai il disco. È il primitivo che usa il malware
fileless vero. Un read-only filesystem qui non serve a NIENTE — non sto scrivendo sul disco. E AppArmor? Guarda i
FILE, non le syscall: è cieco su questo."
Onestà (importante): "L'handler è BENIGNO apposta: crea il file in RAM e vi dice che il primitivo è disponibile.
Non esegue un payload attaccante — mi fermo qui per restare nei tempi e non portare un exploit reale sul palco.
Il punto di sicurezza è che il primitivo ESISTE, non serve altro."
-->

---

## Demo — fileless: disponibile, poi **negato** da Seccomp

<span class="tag demo">DEMO · Docker</span> Stesso primitivo, due container affiancati

<div class="term" data-title="app-go-distroless · :6664">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-go-distroless · :6664</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-go.sh app-go-distroless</span><span class="fail">[ATTACK SUCCEEDED - HTTP 200]</span>
[SUCCEEDED] fileless primitive available</pre>
</div>

<div class="term" data-title="app-go-distroless-hardened · :6665">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-go-distroless-hardened · :6665</span><span class="pill green">BLOCCATO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-go.sh app-go-distroless-hardened</span><span class="ok">[ATTACK BLOCKED - HTTP 500]</span>
[BLOCKED] memfd_create denied: operation not permitted</pre>
</div>

Nego la **syscall**, non il file — è un layer diverso da AppArmor.

<!--
[30:00 → 32:15] DEMO su Docker — UN SOLO momento-demo, due container di fila.
1) app-go-distroless (:6664) → ./tests/test-go.sh app-go-distroless → 🔴 [SUCCEEDED] fileless primitive available.
   "Il primitivo esiste, su un binario Go statico distroless. Zero shell, zero toolchain."
2) SUBITO, senza cambiare slide → app-go-distroless-hardened (:6665) → stesso script → 🟢 [BLOCKED] memfd_create denied (EPERM).
   "Il primitivo sparisce. Difesa al layer giusto: AppArmor per i FILE, Seccomp per le SYSCALL."
Reality check (onestà): "un allowlist di syscall è fragile — aggiorno una dipendenza, Go introduce una syscall
nuova per la rete, e in produzione il container crasha con EPERM senza un log chiaro. Nulla è gratis."
-->

---

## Un esempio, non una ricetta
### Il punto non è la lista di syscall: è il *threat model*

<div class="cols">
<div>

Ci fermiamo a **una** syscall (`memfd_create`) per mostrare **come si ragiona**. Ma le vie in-memory sono altre: `memfd_secret`, `mmap`+`mprotect`, `ptrace`…

Un profilo Seccomp serio è un **allowlist**: impegno vero, e **trade-off** reali (troppo stretto → `EPERM` in prod).

</div>
<div>

<span class="small">Candidate al *deny* (sempre da testare):</span>

`memfd_create` · `memfd_secret` · `ptrace` · `bpf` · `unshare` · `mount` · `kexec_load` · `io_uring_setup`

<span class="small">⚠️ Mai `execve`. Verifica sempre che non spacchino il software.</span>

</div>
</div>

> Conta avere un **threat model** e la **consapevolezza onesta** di quanto vale la tua sicurezza.

<!--
[32:15 → 33:15] Slide-concetto (nuova), chiude l'ATTO 4. Onestà + shift di prospettiva.
"Mi sono fermato a una syscall per farvi vedere il ragionamento, non perché sia l'unica. Un profilo vero è un
allowlist, costa impegno e ha trade-off. Il punto non è la lista: è il threat model — sapere contro cosa vi difendete."
Dettagli e tabella completa in notes/docs/07-seccomp-fileless.md.
-->

---

<!-- _header: '' -->

## Scoreboard — dopo l'ATTO 4

<table class="scoreboard">
<thead><tr><th></th><th>classic<br>:6661</th><th>distroless<br>:6662</th><th>hardened<br>:6663</th><th>go-distroless<br>:6664</th><th>go-hardened<br>:6665</th></tr></thead>
<tbody>
<tr><td>cmdi</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>passwd</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>token</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>conf</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>eval</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>fileless</td><td class="na">n/a</td><td class="na">n/a</td><td class="na">n/a</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td></tr>
</tbody>
</table>

<div class="legend"><span class="lk"><span class="sw red"></span>riuscito</span><span class="lk"><span class="sw green"></span>bloccato</span><span class="lk"><span class="sw grey"></span>non ancora testato</span><span class="lk">n/a — attacco non applicabile a quel container</span></div>

<!--
"Ogni layer toglie un anello rosso. Nessuno li toglie tutti. Guardate `eval`, ancora lì, rosso, in mezzo a tutto il verde che abbiamo costruito. Non l'abbiamo dimenticato: ci torniamo in chiusura."
-->

---

<!-- _class: divider alt -->
<!-- header: 'LE ALTRE BUZZWORD' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">§</div>

# Le altre buzzword
<div class="bar"></div>

<p>Per ogni strumento, ogni buzzword del momento: stesso meccanismo, stessa trappola.</p>

<!--
Cambio di registro: usciamo dalle demo tecniche, torniamo al livello "discorso". Ritmo più veloce qui.
-->

---

## «Sono su un **managed** (GKE). Sono protetto?»

**Responsabilità condivisa:** Google protegge l'infrastruttura — nodi, control-plane, patch del kernel.
**Non scrive il tuo codice.** L'LFI e l'`eval` che avete visto girano identici su GKE: sono nell'anello *Code*.

Il managed ti *dà* strumenti veri — ma li devi **attivare e capire**, non arrivano gratis dalla parola "managed":

- **Autopilot** → alza il pavimento con una baseline di sicurezza che non puoi spegnere
- **Sandbox (gVisor)** → un extra strato di isolamento sulle syscall
- **Workload Identity** → token a vita breve invece del token montato per sempre

<span class="statement">Attivo <code>RuntimeDefault</code> su GKE — e il fileless è <em>ancora</em> lì. Serve un profilo <em>custom</em>.</span>

<!--
[33:30 → 35:00] La seconda buzzword smontata.
"'Managed' è forse la parola più fraintesa. Google patcha il kernel, ruota i certificati, protegge l'API server.
Fa un lavoro enorme. Ma NON scrive il tuo codice. L'LFI che avete visto gira identico su GKE.
Il modello si chiama 'shared responsibility': loro l'infrastruttura, TU il workload."
Poi il rovescio positivo: "Il managed però ti DÀ strumenti veri, che però devi ATTIVARE e capire — non arrivano gratis dalla parola 'managed'."
Ripeti tesi: «Più sicuro» non vuol dire «sicuro».

SE TE LO CHIEDONO (non affermare più di così sul palco):
- Autopilot = i nodi li gestisce Google E impone una baseline che non puoi spegnere (es. Seccomp RuntimeDefault sempre attivo, niente container privilegiati). Ma gira sempre il TUO codice: un LFI/eval resta.
- Sandbox = gVisor: un "kernel finto" in Go tra container e kernel dell'host. Intercetta le syscall in userspace e ne passa al kernel vero solo un sottoinsieme sicuro → molto più difficile evadere, mitiga davvero attacchi syscall come il fileless. Costo: un po' di prestazioni.
- Workload Identity = il pod ottiene token a vita breve invece del token del service account montato per sempre → se te lo rubano, scade presto.
- TOKEN EFFIMERI (se te lo chiedono): storicamente K8s montava in ogni pod un token del service account a VITA LUNGA (/var/run/secrets/.../token, il JWT che leggi nella demo LFI) — mai scaduto, quindi rubarlo = accesso "per sempre" + movimento laterale. "Effimero" = a vita breve (BoundServiceAccountTokens, default da K8s 1.22): scade in fretta (es. 1h), è legato a QUEL pod e viene ruotato automaticamente. Se te lo rubano dura poco e vale solo lì → il blast radius crolla. In una frase: dura poco, si rinnova da solo, scade in fretta.

✅ VERIFICATO DAL VIVO (2026-09-25, cluster caw, GKE 1.35, e2-micro): RuntimeDefault NON blocca memfd_create.
In entrambi i tempi l'endpoint dà HTTP 200 [SUCCEEDED]. Il profilo di default di containerd/GKE consente memfd_create.
Beat da spendere con sicurezza: "Sono su managed, ho pure attivato RuntimeDefault — e il primitivo fileless è ANCORA lì.
'Ho Seccomp attivo' non vuol dire 'ho Seccomp contro QUESTO'. Serve un profilo custom (type: Localhost) che neghi memfd_create."
Se vuoi mostrarlo dal vivo su GKE: kubectl patch ...RuntimeDefault → port-forward → curl (resta rosso). Dettagli e comandi in notes/docs/gke-setup.md.
-->

---

## «Uso la libreria X perché è **più sicura**»
### La supply chain

Non puoi auditare l'**intero albero** delle dipendenze.

**2016 — `left-pad`:** un pacchetto npm di **11 righe** ritirato dall'autore → si rompe mezza internet. *Una dipendenza che **sparisce**.*

**2024 — `xz-utils` / CVE-2024-3094:** backdoor inserita a monte, in una libreria di compressione, da un manutentore "fidato". *Una dipendenza che **diventa ostile**.*

<!--
[35:00 → 37:30] La terza buzzword.
"'Fastify è più sicuro di Express' — magari è vero, ma è un'opinione, non un threat model.
Il problema vero: la tua app tira dentro centinaia di dipendenze transitive. Non le leggi tutte.
Nel 2024 xz — una libreria di compressione ovunque — è stata backdoorata da un manutentore che si era
costruito fiducia per due anni. Nessuna 'immagine più sicura' ti avrebbe salvato."
Aggancio: "Se non puoi fidarti della catena a monte, ti servono difese a valle, a runtime.
Se la lib è bucata, AppArmor/Seccomp limitano cosa il processo compromesso può fare."
Battuta opzionale: "Nel 2016 uno ha ritirato un pacchetto di 11 righe e ha rotto mezza internet. Voi vi fidate delle vostre dipendenze?"
-->

---

## Il filo conduttore

Se **non puoi fidarti** del claim a monte...
...ti servono difese **a valle**, a runtime.

Distroless + AppArmor + Seccomp + RBAC = **anelli**.
Nessuno basta da solo. Insieme = **defense in depth**.

> **Non è una checklist: è un modo di ragionare.**
> Aggiungi strati di sicurezza uno sull'altro, e trasforma la sicurezza in un **processo** che migliora nel tempo — non in una casella spuntata una volta.

<span class="small">Su questo — capabilities, limiti di risorse, tutti gli strati Docker — un bel pezzo del mio collega <b>Matteo Madeddu</b>: <code>madeddu.xyz</code></span>

<!--
[37:30 → 38:30]
Sintesi della difesa in profondità. "Non è UNA cosa. È stratificare, sapendo che ogni strato può cedere."
Mantra (se vuoi martellarlo): "L'anello più debole di una catena di sicurezza equivale alla sicurezza dell'intero sistema."
Citazione al volo (collega): "Se volete andare più a fondo sull'hardening Docker — le capabilities, i limiti di risorse, cose che oggi non ho toccato — il mio collega Matteo Madeddu ha scritto un pezzo molto buono." (link nei riferimenti finali)
-->

---

<!-- _class: divider -->
<!-- header: 'CHIUSURA' -->
<!-- _header: '' -->

<div class="kicker">Container at War</div>
<div class="num">eval</div>

# Il conto in sospeso
<div class="bar"></div>

<p>Un attacco non l'abbiamo mai chiuso. È rimasto rosso ovunque. Vediamo perché — e dove si ripara davvero.</p>

<!--
Ultima transizione prima del gran finale. Tono: si torna al bug che non abbiamo mai chiuso.
-->

---

## Il gancio che resta aperto: `eval`

<span class="tag demo">DEMO · Docker</span>

<div class="term" data-title="app-distroless-hardened · :6663">
<div class="term-bar"><span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span><span class="term-label">app-distroless-hardened · :6663</span><span class="pill red">RIUSCITO</span></div>
<pre class="term-out"><span class="cmd">./tests/test-node.sh app-distroless-hardened eval</span><span class="fail">[ATTACK SUCCEEDED - HTTP 200]</span>
RCE result: 2</pre>
</div>

- AppArmor guarda i **file**, non l'interprete JS → non lo vede
- Seccomp userebbe le **stesse syscall legittime** dell'app (`openat`, `read`) → non si può bloccare senza romperla

<span class="statement">Bug di <em>Codice</em>. Si ripara solo allo <em>shift-left</em>.</span>

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

<!-- _header: '' -->

## Scoreboard finale

<table class="scoreboard">
<thead><tr><th></th><th>classic<br>:6661</th><th>distroless<br>:6662</th><th>hardened<br>:6663</th><th>go-distroless<br>:6664</th><th>go-hardened<br>:6665</th></tr></thead>
<tbody>
<tr><td>cmdi</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="cell-grey dash">—</td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>passwd</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>token</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>conf</td><td class="cell-grey dash">—</td><td class="cell-grey dash">—</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td><strong>eval</strong></td><td class="cell-red cell-emph"><span class="pill red">RIUSCITO</span></td><td class="cell-red cell-emph"><span class="pill red">RIUSCITO</span></td><td class="cell-red cell-emph"><span class="pill red">RIUSCITO</span></td><td class="na">n/a</td><td class="na">n/a</td></tr>
<tr><td>fileless</td><td class="na">n/a</td><td class="na">n/a</td><td class="na">n/a</td><td class="cell-red"><span class="pill red">RIUSCITO</span></td><td class="cell-green"><span class="pill green">BLOCCATO</span></td></tr>
</tbody>
</table>

<div class="legend"><span class="lk"><span class="sw red"></span>riuscito</span><span class="lk"><span class="sw green"></span>bloccato</span><span class="lk"><span class="sw grey"></span>non ancora testato</span><span class="lk">n/a — non applicabile</span></div>

<!--
Tabella di chiusura: il colpo d'occhio finale. Ogni layer ha spento almeno un rosso — tranne uno.
`eval` è rosso ovunque sia applicabile: è l'unica riga cerchiata, ed è voluto.
Nota sui dati: la cella "classic / eval" non è stata ri-eseguita dal vivo in questo run (il classic non ha alcuna mitigazione,
quindi il risultato è certo) — è l'unica inferenza della tabella, per chiudere il quadro. Tutte le altre celle colorate sono demo viste sul palco.
"Guardate questa riga. È l'unica che non ho mai spento, con NESSUN layer. Non perché non ci ho provato — perché è nel posto sbagliato per essere risolta lì. È un bug di codice. Si ripara prima, non dopo."
-->

---

## Trovarli **prima** della produzione
### Security review aumentata dall'AI — Argus

Come trovi un LFI, un `eval`, un memfd nel codice *prima* del deploy? **Static analysis.**

<div class="cols">
<div>

**Tool maturi**
- Semgrep — pattern semantici cross-linguaggio
- CodeQL — query strutturali (GitHub)
- gosec (Go) · Bandit (Python)
- ESLint security (JS/TS)
- Gitleaks — segreti nel repo
- OSV-Scanner — vulnerabilità nelle dipendenze

</div>
<div>

**Argus**
Mette insieme questi tool e ci aggiunge il ragionamento dell'AI per correlare e dare priorità ai risultati.

L'AI propone, **la persona decide**: un umano nel loop, sempre.

È il progetto che vi ha raccontato **Davide Imola** — ci ricolleghiamo a quello.

<span class="small">`github.com/argusappsec/argus`</span>

</div>
</div>

<!--
[39:30 → 41:30]
Chiudi il cerchio: "Tutti i bug di oggi sono nel CODICE — command injection, LFI, eval, persino il fileless Go.
Il posto migliore per fermarli è la review, PRIMA del deploy, non a runtime."
"Il mondo static-analysis è pieno di strumenti maturi: Semgrep per pattern semantici cross-linguaggio, CodeQL di GitHub
per query strutturali profonde, gosec se scrivete Go, Bandit se scrivete Python, i plugin di sicurezza di ESLint per JS/TS,
Gitleaks per beccare segreti finiti nel repo, OSV-Scanner per le vulnerabilità nelle dipendenze."
"Argus — il progetto che vi ha appena raccontato Davide Imola — orchestra diversi di questi tool (Semgrep, Gitleaks, OSV-Scanner)
e ci aggiunge un livello di ragionamento AI per correlare e prioritizzare i risultati. Ma — esattamente come per l'allowlist
AppArmor di prima — SEMPRE con un umano nel loop: l'AI accelera la review, non la sostituisce."
"Noi umani ci perdiamo un eval in mezzo a 10.000 righe. L'AI aiuta a trovarlo. Ma la decisione finale resta umana."
NOTA: Davide parla PRIMA di me, quindi mi ricollego al suo talk (passato), non lo anticipo.
-->

---

<!-- _header: '' -->

## La tesi, di nuovo

<span class="statement">«Più sicuro» <em>non vuol dire</em> «sicuro».</span>

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

<!-- _header: '' -->
<!-- _class: dense -->

## Riferimenti — concetti & standard

<div class="cols">
<div>

- **NIST SP 800-190** — Application Container Security Guide
- **Kubernetes** — Overview of Cloud Native Security (le 4C)
- **OWASP** — Path Traversal · Top 10 · Docker/K8s Cheat Sheet

</div>
<div>

- **GoogleContainerTools/distroless**
- **GKE** — Shared responsibility · Autopilot · Sandbox (gVisor) · Workload Identity
- **CVE-2024-3094** (xz backdoor) · **MITRE ATT&CK T1620**

</div>
</div>

<!--
[43:00 → 43:30] Lascia questa slide (o la successiva) su durante le domande.
-->

---

<!-- _header: '' -->

## Riferimenti — tool & repo

- Static analysis: **Semgrep** · **CodeQL** · **gosec** · **Bandit** · **Gitleaks** · **OSV-Scanner**
- **Argus** — security review aumentata dall'AI (talk di Davide Imola) · `github.com/argusappsec/argus`
- Skill Seccomp/AppArmor (osserva → genera → rivedi): `github.com/gafreax/skill-seccomp-apparmor-profiler`
- Hardening Docker (capabilities, limiti risorse, least privilege): **Matteo Madeddu** — `madeddu.xyz/posts/docker-security`

<!--
Seconda metà dei riferimenti, spostata qui per non affollare la slide precedente. Puoi lasciare questa attiva durante il Q&A.
-->

---

<!-- _class: lead -->
<!-- _header: '' -->

## Grazie!
# Domande?

<span class="small">Le slide e il codice della demo sono nel repo.</span>

<!-- IMMAGINE DI CHIUSURA: pinguino (Tux) che picchia col battipanni il logo Claude umanizzato che scappa.
     Genera con nano-banana/Gemini (prompt in notes/frasi-speaker.md §4) e inserisci qui come <img>. -->

<!--
[43:30 → 45:00+] Q&A.
BATTUTA DI CHIUSURA — la fa l'IMMAGINE (pinguino vs Claude). Tu la dici a voce, in chiusura, secca:
>>> "NESSUN PINGUINO È STATO MALTRATTATO IN QUESTA PRESENTAZIONE. MOLTI AI AGENT SÌ." <<<
(la frase NON è più a schermo: la porta l'immagine + la tua voce. Tono leggero, mentre parte l'applauso.)
Ripassa prima le "domande scomode" in docs/04-review-opus.md (sez. 6):
Distroless inutile? / GKE mi protegge? / Autopilot? / gVisor? / perché non un WAF? /
AppArmor su managed? / il token è reale? / read-only non basta? / non-root? /
NUOVA: "chi ha eseguito quel codice Go?" → risposta pronta nella slide di framing dell'ATTO 4 (eval / supply chain / Seccomp = difesa post-exploitation, non prima linea).
-->
