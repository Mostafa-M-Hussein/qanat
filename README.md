# qanat

> القناة - the underground channel that carries water across the desert.

run downloads and media on a fast vps. stream them back over a slow link.
built for egypt-tier last-mile internet.

العربية: [README.ar.md](./README.ar.md)

## what's in it

- **homepage** - one dashboard linking out to everything below
- **aria2-pro** + **ariang** - multi-connection http/bt downloads
- **metube** - yt-dlp web ui (youtube + 1000 other sites)
- **jellyfin** - video streaming
- **navidrome** - music streaming (optional)
- **opencloud** - files, sharing, sync (eu fork of owncloud infinite scale)
- **collabora** - online office editor for opencloud docs (optional)
- **keycloak** + **oauth2-proxy** OR **authelia** - one-login gate (optional)
- **caddy** - tls reverse proxy with letsencrypt + basic auth
- **cloudflared** - optional cf tunnel (no open ports)
- **warp** - optional socks5 to bypass yt's datacenter ip block

## why

if your link to youtube/mega is bad but your link to a single eu vps is fine,
let the vps do the heavy download once, then pull/stream from it. a 4 gb iso
that takes hours direct downloads in seconds on the vps's gigabit pipe, and
you get a stable local-region peer to pull from afterwards.

```
egypt last-mile  <-- ssh tunnel / tls -->  vps  <-- gigabit -->  internet
                                            |
                                       aria2 / yt-dlp
                                            |
                                       jellyfin / sshfs
```

## quick start

```bash
git clone https://github.com/Mostafa-M-Hussein/qanat.git
cd qanat
./setup.sh
$EDITOR .env

# generate a basic-auth hash
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-pw'
# paste output into BASIC_AUTH_HASH in .env

# point dns at the vps:
#   example.com           A  <vps-ip>   (homepage)
#   jellyfin.example.com  A  <vps-ip>
#   aria.example.com      A  <vps-ip>
#   metube.example.com    A  <vps-ip>
#   cloud.example.com     A  <vps-ip>   (opencloud)

# open firewall: 80, 443, 443/udp, 6888 (bt)

docker compose up -d
```

optional add-ons:

```bash
docker compose --profile music up -d     # + navidrome
docker compose --profile warp up -d      # + warp socks5 (yt bypass)
docker compose --profile tunnel up -d    # + cloudflare tunnel
docker compose --profile office up -d    # + collabora office editor
docker compose --profile sso up -d       # + keycloak + oauth2-proxy gate
docker compose --profile authelia up -d  # + authelia (lighter alternative)
```

sso setup steps live in [docs/sso.md](./docs/sso.md). already running aria2
or jellyfin and want to switch over without re-downloading? see
[docs/migration.md](./docs/migration.md).

## three ways to reach a service

every service except caddy and the bt port binds to `127.0.0.1`. you reach
them via:

1. **caddy** - public, tls, basic-auth where it matters
2. **ssh tunnel** - private, no public surface:
   ```bash
   ssh -L 6880:localhost:6880 -L 8081:localhost:8081 -L 8096:localhost:8096 user@vps
   ```
3. **cloudflare tunnel** - `--profile tunnel`, no open ports at all

## why metube goes through warp

youtube blocks most datacenter ips:

```
ERROR: [youtube] xxxx: Sign in to confirm you're not a bot.
```

`--profile warp` adds a free cloudflare warp socks5 on `warp:1080`. the
default `METUBE_YTDL_OPTIONS` already routes through it.

aria2 over warp - add to `aria2-config/aria2.conf`:

```
all-proxy=socks5://warp:1080
```

## sharing with friends

this compose gives one stack to one admin. for friends, see
[docs/per-user-isolation.md](./docs/per-user-isolation.md). short version:

- give them a jellyfin user only (no shell, no downloads), or
- give them an ssh user locked to port-forwarding (no shell, can tunnel
  to the loopback ports), or
- give them a full incus/lxc container with disk + bandwidth quotas

never give a friend a real shell on the host.

## hardening checklist

- [ ] `ARIA2_RPC_SECRET` is random (setup.sh handles this)
- [ ] `BASIC_AUTH_HASH` is set
- [ ] jellyfin admin password is set on first-run
- [ ] firewall: only 80, 443, bt port open
- [ ] crowdsec or fail2ban on caddy logs
- [ ] backups of `aria2-config/`, `jellyfin/config/`, `caddy/data/`

## troubleshooting

**jellyfin transcodes everything and the cpu melts.**
force direct play: jellyfin admin -> playback -> transcoding, set hw accel
to none. pre-transcode at download time with metube's post-processor or a
cron `ffmpeg`.

**caddy won't get a cert.**
80 and 443 must be reachable, dns for `*.${DOMAIN}` must point at the vps.
check `docker logs qanat-caddy`.

**metube fails with "sign in to confirm you're not a bot".**
add a real `cookies.txt` (browser extension export) or use `--profile warp`.

**aria2 bt has no peers.**
the bt port (`ARIA2_BT_PORT`, default 6888) must be reachable from the
public internet. open it on your host firewall.

## license

mit. see [LICENSE](./LICENSE).
