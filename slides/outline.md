# Scaletta Talk: Container at War (Distroless & Hardening)

## 1. Intro: Il mito Distroless e Zero Trust
- Cos'è una Distroless? (Niente shell `/bin/sh`, niente `apt`/`apk`, niente tool come `curl` o `wget`).
- I vantaggi: Superficie di attacco ridotta.
- L'errore comune: Pensare che "Niente shell" significhi "Impossibile da attaccare" (fidarsi ciecamente dei claim).

## 2. La (falsa) Sicurezza: Demo RCE Classica vs Distroless
- **L'Attacco (Classico):** Immagine Node.js standard. Sfruttiamo un bug Command Injection (`/api/v1/ping`) passando `ip=8.8.8.8; ls -la`. Otteniamo il controllo.
- **L'Attacco (Distroless):** Proviamo lo stesso attacco su Distroless. Fallisce miseramente con `spawn /bin/sh ENOENT`.
- **Takeaway:** La riduzione della superficie di attacco funziona! Distroless ci ha appena protetto.

## 3. Discorso Sicurezza: La catena debole e OWASP
- La sicurezza è una catena. I layer sono tanti (Code, Container, Cluster, Cloud).
- Escursus breve su OWASP (Injection, Path Traversal, Insecure Deserialization).
- Non possiamo fermarci a "ho messo distroless, sono a posto".

## 4. L'Illusione cade: Demo LFI su Distroless
- **L'Attacco:** Sfruttiamo un Local File Inclusion (`/api/v1/download`). Node.js non ha bisogno di Bash per leggere un file!
- **La Battuta Nerd:** Leggiamo `/etc/passwd` e mostriamo al pubblico che sul server c'è l'utente *darth_vader* con la shell `/bin/force_choke` o *neo* in `/matrix`.
- **Il Danno VERO:** Con lo stesso attacco leggiamo il token K8s. Il cluster è compromesso.

## 5. Il Colpo di Grazia: Demo Go RCE Fileless
- Anche senza bash, si può avere RCE in Distroless? Sì.
- Demo dell'attacco `memfd_create` in Go. Esecuzione di codice direttamente in memoria.

## 6. L'Hardening Salva la Giornata (Live K8s)
- AppArmor blocca le azioni al File System.
- Applichiamo AppArmor live su Minikube (o Docker).
- Ritentiamo l'LFI: Fallisce! Il Kernel Linux intercetta e blocca Node.js.
- Seccomp blocca le chiamate di sistema: addio attacco Go Fileless.

## 7. Il Problema della Supply Chain (CVE e Librerie)
- *Battuta Nerd:* "Express.js non mi fa impazzire, Fastify è meglio anche per la sicurezza!" (ma se anche Fastify avesse un bug 0-day?).
- Esempio di una CVE nota su una libreria.
- Dimostrazione che se il framework che usi ha una vulnerabilità, Distroless non ti salva. Ma AppArmor/Seccomp sì, perché bloccano il perimetro del processo.

## 8. L'aiuto dell'Intelligenza Artificiale: Argus
- Come facciamo a trovare questi bug nel codice prima che vadano in produzione?
- Assist al talk precedente di Davide Imola.
- Presentazione di Argus, tool CLI `gotrova`, e skill di Claude/Antigravity/Codex per fare security review aumentata. (Rif: `github.com/gafreax/gotrova/cmd/gotrova@latest`).

## 9. Chiusura e Riferimenti
- Domande (poche, speriamo di essere andati lunghi col Nerdaggio!).
