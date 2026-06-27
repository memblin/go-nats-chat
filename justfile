# nats-chat-console — project tasks. Run `just` with no recipe to see this list.

# Name of the console binary.
console-bin := "nats-chat-console"

# Default: list available recipes.
default:
    @just --list

# Build the console TUI into the repo root.
build:
    go build -o {{console-bin}} ./cmd/nats-chat-console

# Build the console via `go build ./...` (no output binary, just a compile check).
check:
    go build ./...
    go vet ./...

# Run unit tests (no NATS server required).
test:
    go test -race ./...

# Run all tests including the JetStream integration suite (spins up a local NATS container).
test-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    container="nats-go-nats-chat-test"
    port=14222
    cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
    trap cleanup EXIT
    cleanup
    docker run -d --name "$container" -p ${port}:4222 nats:latest -js >/dev/null
    echo "Waiting for NATS..."
    for i in $(seq 1 30); do
        if docker exec "$container" nats-server --help >/dev/null 2>&1; then
            sleep 1; break
        fi
        sleep 1
    done
    NATS_TEST_URL="nats://127.0.0.1:${port}" go test -race -v ./...

# Install the console binary onto $(go env GOPATH)/bin.
install:
    go install ./cmd/nats-chat-console

# Format all Go source files.
fmt:
    gofmt -w .

# Run golangci-lint (must be installed separately).
lint:
    golangci-lint run ./...
