# Stage 1: build a static Go binary
FROM golang:1.27 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /demo-go .

# Stage 2: distroless static (no shell, no libc, just the binary)
FROM gcr.io/distroless/static-debian13
COPY --from=builder /demo-go /demo-go
EXPOSE 8080
ENTRYPOINT ["/demo-go"]
