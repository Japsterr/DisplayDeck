#!/usr/bin/env bash
set -euo pipefail

WITH_TUNNEL="${WITH_TUNNEL:-}"
RUN_MIGRATIONS="${RUN_MIGRATIONS:-false}"

if [[ ! -f .env ]]; then
  echo "Missing .env in repo root. Copy .env.example to .env and set required values." >&2
fi

compose_files=(-f docker-compose.prod.yml)

# By default, bring up the Cloudflare tunnel on prod when a token is configured.
auto_tunnel="false"
if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
  auto_tunnel="true"
elif [[ -f .env ]]; then
  if grep -E '^\s*TUNNEL_TOKEN\s*=\s*[^#\s]+' .env >/dev/null 2>&1; then
    auto_tunnel="true"
  fi
fi

if [[ "$WITH_TUNNEL" == "true" || "$auto_tunnel" == "true" ]]; then
  compose_files+=(-f docker-compose.tunnel.yml)
fi

echo "Rebuilding and restarting containers..."
docker compose --env-file .env "${compose_files[@]}" up -d --build

if [[ "$RUN_MIGRATIONS" == "true" ]]; then
  echo "Running DB migrations..."
  docker compose --env-file .env "${compose_files[@]}" --profile migrate up --abort-on-container-exit db-migrate
fi

echo "Done. Verify the Menu Editor shows 'UI build: ...' under Template."
