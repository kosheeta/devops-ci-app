#!/usr/bin/env bash
set -euo pipefail

image=${1:?Pass the image reference}
port=${2:-5000}
name="devops-ci-smoke-$$"
health=$(mktemp)

cleanup() {
    docker logs "$name" 2>/dev/null || true
    docker rm -f "$name" >/dev/null 2>&1 || true
    rm -f "$health"
}
trap cleanup EXIT

docker run -d --name "$name" -p "127.0.0.1:$port:5000" "$image"
for ((attempt = 1; attempt <= 15; attempt++)); do
    if curl -fsS --max-time 2 "http://127.0.0.1:$port/health" -o "$health"; then
        python3 -m json.tool "$health"
        python3 -c 'import json, sys; assert json.load(sys.stdin) == {"status": "ok"}' < "$health"
        docker exec "$name" id
        test "$(docker exec "$name" id -u)" -ne 0
        exit 0
    fi
    if [[ $(docker inspect --format '{{.State.Running}}' "$name") == false ]]; then
        break
    fi
    sleep 1
done
echo "ERROR: /health did not respond" >&2
exit 1
