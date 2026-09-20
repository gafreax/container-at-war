# Stage 1: Build (use a standard Node image to get npm)
FROM node:24 AS builder
WORKDIR /app
COPY package.json ./
RUN npm install
COPY server.js ./

# Stage 2: Distroless (minimal image, no shell)
FROM gcr.io/distroless/nodejs24-debian13
WORKDIR /app
COPY --from=builder /app /app
EXPOSE 8080
# Distroless: invoke server.js directly via the built-in "node" entrypoint
CMD ["server.js"]
