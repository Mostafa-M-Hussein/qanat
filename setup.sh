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
    media/{Movies,TV,Music,YouTube,Downloads} \
    jellyfin/config jellyfin/cache \
    navidrome/data \
    opencloud/config opencloud/data \
    homepage/icons \
    examples

if [[ ! -f examples/cookies.txt.example ]]; then
    cat > examples/cookies.txt.example <<'EOF'
# Netscape HTTP Cookie File
# replace with a real export from your browser if you need
# age-gated / login-required youtube downloads.
EOF
fi

# homepage cards - copy template if user hasn't customized one yet
if [[ ! -f homepage/config/services.yaml && -f homepage/config/services.yaml.example ]]; then
    cp homepage/config/services.yaml.example homepage/config/services.yaml
    yellow "==> created homepage/config/services.yaml - edit hrefs to your real subdomains"
fi

if [[ ! -f .env ]]; then
    green "==> generating .env"
    cp .env.example .env

    if command -v openssl >/dev/null 2>&1; then
        secret=$(openssl rand -hex 24)
        sed -i.bak "s|ARIA2_RPC_SECRET=.*|ARIA2_RPC_SECRET=${secret}|" .env
        rm -f .env.bak
        green "    aria2 rpc secret generated"
    fi

    yellow ""
    yellow "    .env created. before starting, set:"
    yellow "      DOMAIN, ACME_EMAIL, JELLYFIN_URL"
    yellow "      BASIC_AUTH_HASH (docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-pw')"
    yellow "      OC_ADMIN_PASSWORD (8+ chars, mixed case + digit + special)"
fi

cat <<'EOF'

==> done.

next:
  1. edit .env
  2. point dns at this vps for *.DOMAIN
  3. open firewall: 80, 443, 443/udp, 6888 (bittorrent)
  4. docker compose up -d

optional:
  docker compose --profile music up -d     # navidrome
  docker compose --profile office up -d    # collabora editor for opencloud
  docker compose --profile warp up -d      # warp socks5 (yt bypass)
  docker compose --profile tunnel up -d    # cloudflare tunnel (no open ports)

EOF
