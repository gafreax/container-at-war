const fastify = require('fastify')({ logger: true });
const fs = require('fs');
const { exec } = require('child_process');

// 1. Command Injection classica (via exec -> richiede /bin/sh)
//    - Su immagine CLASSICA: l'attacco RIESCE (la shell c'è, il comando iniettato gira)
//    - Su immagine DISTROLESS: l'attacco FALLISCE con ENOENT
//      ("Error NO ENTry": il file /bin/sh non esiste, Node non può lanciarlo)
fastify.get('/attack/command-injection', (request, reply) => {
    const ip = request.query.ip || '8.8.8.8';
    exec(`ping -c 1 ${ip}`, (error, stdout, stderr) => {
        if (error) {
            return reply.code(500).send(`[FALLITO] Errore: ${error.message}\n`);
        }
        return reply.send(stdout);
    });
});

// 2. LFI / Path Traversal (via fs.readFileSync -> NON richiede nessuna shell)
//    - Su immagine DISTROLESS: l'attacco RIESCE lo stesso (è codice Node puro)
//    - Su immagine HARDENED (+AppArmor): l'attacco FALLISCE con EACCES
//      ("Error ACCESs": il file esiste, ma il kernel nega il permesso di lettura)
fastify.get('/attack/path-traversal', async (request, reply) => {
    try {
        return reply.send(fs.readFileSync(request.query.file, 'utf8'));
    } catch (err) {
        return reply.code(500).send(`Errore di lettura: ${err.code || err.message}\n`);
    }
});

// 3. RCE vera (Esecuzione Arbitraria di Codice JS via eval -> NON richiede nessuna shell)
// Permette a un attaccante di far eseguire a Node.js qualsiasi istruzione,
// sfruttando moduli nativi (es. fs, net) e aggirando completamente l'assenza di /bin/sh.
fastify.get('/attack/eval-rce', (request, reply) => {
    try {
        const payload = request.query.code;
        // ERRORE CRITICO: esecuzione di codice arbitrario non sanitizzato.
        const result = eval(payload);
        return reply.send(`Risultato RCE:\n${result}\n`);
    } catch (err) {
        return reply.code(500).send(`Errore RCE: ${err.message}\n`);
    }
});

fastify.listen({ port: 8080, host: '0.0.0.0' })
    .then(() => console.log('Fastify API in ascolto su porta 8080 (Distroless)'))
    .catch(err => process.exit(1));
