---
marp: true
theme: default
class: lead
paginate: true
backgroundColor: #fff
style: |
  section {
    justify-content: center;
  }
---

# Container at War 
## Distroless & Hardening
<br>

---

## 1. Il Mito Distroless

---

### Cos'è una Distroless?

---

### Nessuna Shell
`/bin/sh` non esiste.

---

### Nessun Package Manager
Addio `apt` o `apk`.

---

### Nessuna Utility
Niente `curl`, niente `wget`.

---

### Il Vantaggio
Una superficie di attacco **estremamente ridotta**.

---

### Ma c'è un errore comune...

---

### L'Illusione della Sicurezza
Pensare che "Niente shell" significhi "Impossibile da attaccare".

---

## 2. La (Falsa) Sicurezza: <br> RCE Classica vs Distroless

---

### Lo Scenario
Un'immagine Node.js standard.

---

### L'Attacco Classico
Un bug di Command Injection sull'endpoint `/api/v1/ping`.

---

### Il Payload
`ip=8.8.8.8; ls -la`

---

### Il Risultato
Otteniamo il controllo. Abbiamo una shell.

---

### E con Distroless?

---

### L'Attacco fallisce.
`spawn /bin/sh ENOENT`

---

### Vittoria!
Distroless ha bloccato l'attacco. 

*(Fine della presentazione?)*

---

## 3. La Sicurezza è una Catena

---

### Code 
### Container 
### Cluster 
### Cloud

---

### OWASP Top 10 non dorme mai
- Injection
- Path Traversal
- Insecure Deserialization

---

### "Ho messo distroless, sono a posto"
Un mito da sfatare.

---

## 4. L'Illusione cade: <br> Demo LFI su Distroless

---

### Il Nuovo Vettore
Local File Inclusion (LFI) su `/api/v1/download`.

---

### Node.js non ha bisogno di Bash
I moduli nativi leggono il file system direttamente.

---

### L'Easter Egg
Leggiamo `/etc/passwd`.

---

### Sorpresa
C'è l'utente *darth_vader* con la shell `/bin/force_choke`.

---

### Il Danno Vero
Cosa succede se leggiamo `/var/run/secrets/kubernetes.io/serviceaccount/token`?

---

### Cluster Compromesso
Senza usare una singola shell.

---

## 5. Il Colpo di Grazia: <br> Go RCE Fileless

---

### RCE senza Bash su Distroless?
Sì. È possibile.

---

### L'approccio Fileless
Sfruttare `memfd_create` in Go.

---

### Esecuzione in memoria
Il codice viene eseguito direttamente in RAM, bypassando completamente il file system.

---

## 6. L'Hardening Salva la Giornata

---

### AppArmor
Blocca le azioni al File System a livello di Kernel.

---

### Demo: AppArmor su Minikube

---

### Ritentiamo l'LFI
Il Kernel Linux intercetta e blocca Node.js.

---

### E per gli attacchi in memoria?
AppArmor non basta.

---

### Seccomp
Filtra le chiamate di sistema (Syscalls).

---

### L'Antidoto
Seccomp blocca l'attacco Go Fileless alla radice.

---

## 7. La Supply Chain

---

### "Uso Fastify, è più sicuro di Express"
Le librerie non sono perfette.

---

### Vulnerabilità Zero-Day
Se il framework ha una falla, Distroless non ti salva.

---

### Difesa in Profondità
AppArmor e Seccomp limitano i danni *post-exploit*.

---

## 8. L'aiuto dell'AI: Argus

---

### Come prevenire tutto questo?
Trovando i bug *prima* della produzione.

---

### Security Review Aumentata
L'uso dell'Intelligenza Artificiale nel codice.

---

### Tool CLI: gotrova
`github.com/gafreax/gotrova/cmd/gotrova@latest`

---

## 9. Q&A

---

### Grazie!
Domande?
