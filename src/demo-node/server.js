const fastify = require('fastify')({ logger: true });
const fs = require('fs');
const { exec } = require('child_process');

// 1. Falsa RCE (Command Injection classica) -> FALLISCE su Distroless
fastify.get('/api/v1/ping', (request, reply) => {
    const ip = request.query.ip || '8.8.8.8';
    exec(`ping -c 1 ${ip}`, (error, stdout, stderr) => {
        if (error) {
            return reply.code(500).send(`[BLOCCATO DA DISTROLESS] Errore: ${error.message}\n`);
        }
        return reply.send(stdout);
    });
});

// 2. LFI (Path Traversal) -> FUNZIONA su Distroless, ma viene BLOCCATO da AppArmor
fastify.get('/api/v1/download', async (request, reply) => {
    try {
        return reply.send(fs.readFileSync(request.query.file, 'utf8'));
    } catch (err) {
        return reply.code(500).send("Errore di lettura.\n");
    }
});

// 3. VERA RCE (Esecuzione Arbitraria di Codice JS) -> FUNZIONA su Distroless
// Permette a un attaccante di far eseguire a Node.js qualsiasi istruzione
fastify.get('/api/v1/eval', (request, reply) => {
    try {
        const payload = request.query.code;
        // ERRORE CRITICO: Esecuzione di codice arbitrario non sanitizzato.
        // L'attaccante può passare codice JS che sfrutta moduli nativi (es. fs, net) 
        // aggirando completamente il fatto che manchi /bin/sh.
        const result = eval(payload);
        return reply.send(`Risultato RCE:\n${result}\n`);
    } catch (err) {
        return reply.code(500).send(`Errore RCE: ${err.message}\n`);
    }
});

fastify.listen({ port: 8080, host: '0.0.0.0' })
    .then(() => console.log('Fastify API in ascolto su porta 8080 (Distroless)'))
    .catch(err => process.exit(1));
