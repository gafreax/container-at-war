# Fase 1: Build (usiamo un'immagine Node standard per avere npm)
FROM node:20 AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY server.js ./

# Fase 2: Distroless (immagine minimale, sicura e senza shell)
FROM gcr.io/distroless/nodejs20-debian11
WORKDIR /app
COPY --from=builder /app /app
EXPOSE 8080
# Siccome è distroless, invochiamo direttamente il binario "node" che esegue server.js
CMD ["server.js"]
