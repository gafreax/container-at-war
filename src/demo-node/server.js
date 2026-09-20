const fastify = require('fastify')({ logger: true });
const fs = require('fs');
const { exec } = require('child_process');

// 1. Classic Command Injection (via exec -> needs /bin/sh)
//    - Classic image:    attack SUCCEEDS (the shell exists, the injected command runs)
//    - Distroless image: attack FAILS with ENOENT
//      ("Error NO ENTry": /bin/sh does not exist, Node cannot spawn it)
fastify.get('/attack/command-injection', (request, reply) => {
    const ip = request.query.ip || '8.8.8.8';
    exec(`ping -c 1 ${ip}`, (error, stdout, stderr) => {
        if (error) {
            return reply.code(500).send(`[FAILED] ${error.message}\n`);
        }
        return reply.send(stdout);
    });
});

// 2. LFI / Path Traversal (via fs.readFileSync -> no shell needed)
//    - Distroless image: attack SUCCEEDS anyway (it is pure Node code)
//    - Hardened image (+AppArmor): attack FAILS with EACCES
//      ("Error ACCESs": the file exists, but the kernel denies read permission)
fastify.get('/attack/path-traversal', async (request, reply) => {
    try {
        return reply.send(fs.readFileSync(request.query.file, 'utf8'));
    } catch (err) {
        return reply.code(500).send(`Read error: ${err.code || err.message}\n`);
    }
});

// 3. True RCE (arbitrary JS execution via eval -> no shell needed)
// Lets an attacker run any instruction inside Node, using native modules
// (e.g. fs, net) and completely bypassing the absence of /bin/sh.
fastify.get('/attack/eval-rce', (request, reply) => {
    try {
        const payload = request.query.code;
        // CRITICAL FLAW: execution of unsanitized arbitrary code.
        const result = eval(payload);
        return reply.send(`RCE result: ${result}\n`);
    } catch (err) {
        return reply.code(500).send(`RCE error: ${err.message}\n`);
    }
});

fastify.listen({ port: 8080, host: '0.0.0.0' })
    .then(() => console.log('Fastify API listening on port 8080'))
    .catch(err => process.exit(1));
