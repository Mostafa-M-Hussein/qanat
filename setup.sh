#!/usr/bin/env bash
# qanat bootstrap - dirs, secrets, .env
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

green "==> creating data directories"
mkdir -p \
    aria2-config \
    caddy/data caddy/config \
    files \
    media/{Movies,TV,Music,YouTube} \
    jellyfin/config jellyfin/cache \
    navidrome/data \
    opencloud/config opencloud/data \
    homepage/icons \
    keycloak/postgres \
    examples

if [[ ! -f examples/cookies.txt.example ]]; then
    cat > examples/cookies.txt.example <<'EOF'
# Netscape HTTP Cookie File
# replace with a real export from your browser if you need
# age-gated / login-required youtube downloads.
EOF
fi

if [[ ! -f .env ]]; then
    green "==> generating .env"
    cp .env.example .env

    if command -v openssl >/dev/null 2>&1; then
        secret=$(openssl rand -hex 24)
        sed -i.bak "s|ARIA2_RPC_SECRET=.*|ARIA2_RPC_SECRET=${secret}|" .env
        rm -f .env.bak
        green "    aria2 rpc secret generated"
    else
        yellow "    openssl missing - set ARIA2_RPC_SECRET in .env manually"
    fi

    yellow ""
    yellow "    .env created. before starting, set:"
    yellow "      DOMAIN, ACME_EMAIL"
    yellow "      JELLYFIN_URL"
    yellow "      BASIC_AUTH_HASH (docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-pw')"
    yellow "      OC_ADMIN_PASSWORD (8+ chars, mixed case + digit + special)"
    yellow "      OC_UID_GID (id -u $USER and id -g $USER on the host)"
else
    yellow "==> .env exists, leaving it alone"
fi

cat <<'EOF'

==> done.

next:
  1. edit .env (DOMAIN, ACME_EMAIL, JELLYFIN_URL, BASIC_AUTH_HASH)
  2. point dns at this vps for *.DOMAIN
  3. open firewall: 80, 443, 443/udp, ARIA2_BT_PORT (default 6888)
  4. docker compose up -d

profiles:
  music    docker compose --profile music up -d
  warp     docker compose --profile warp up -d
  tunnel   docker compose --profile tunnel up -d   (then close 80/443)

EOF
