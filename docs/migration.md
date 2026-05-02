# migrating an existing aria2/jellyfin/navidrome setup to qanat

if you already run aria2-pro, jellyfin, navidrome (or all three) in their own
containers, qanat lets you reuse the data and the existing aria2 RPC secret
without re-downloading or re-indexing anything.

## what to keep

- existing `aria2-config/` directory (server config, sessions, cookies)
- existing aria2 RPC secret (so AriaNG bookmarks keep working)
- existing jellyfin `config/` and `cache/` (library, users, watch history)
- existing navidrome `data/` (database, scanned tracks)
- existing media library on disk

## the strategy: symlink + override

instead of moving gigabytes of data, point qanat at where the data already
lives. two pieces:

1. **symlinks** for the directories the compose file expects under `./`
2. **`docker-compose.override.yml`** for host-specific networking (joining
   the cloudflared/caddy/proxy networks of your existing stack)

`docker-compose.override.yml` is gitignored - this file is per-host.

## step by step

### 1. clone the repo

```bash
git clone https://github.com/Mostafa-M-Hussein/qanat.git
cd qanat
./setup.sh
```

### 2. find your existing values

```bash
# aria2 RPC secret
docker inspect <old-aria2-container> --format '{{range .Config.Env}}{{println .}}{{end}}' | grep RPC_SECRET

# data paths
docker inspect <old-aria2-container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println ""}}{{end}}'
docker inspect <old-jellyfin-container>  --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println ""}}{{end}}'
docker inspect <old-navidrome-container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println ""}}{{end}}'
```

### 3. write `.env` pointing at the existing paths

```env
DOWNLOADS_DIR=/path/to/existing/aria2/files
MEDIA_DIR=/path/to/existing/jellyfin/media
MUSIC_DIR=/path/to/existing/music
COOKIES_FILE=/path/to/existing/cookies.txt

# reuse the existing one
ARIA2_RPC_SECRET=<paste-from-step-2>
```

### 4. symlink the in-tree dirs the compose expects

```bash
rm -rf aria2-config jellyfin
ln -s /path/to/existing/aria2-config aria2-config
mkdir jellyfin
ln -s /path/to/existing/jellyfin/config jellyfin/config
ln -s /path/to/existing/jellyfin/cache  jellyfin/cache
mkdir navidrome
ln -s /path/to/existing/navidrome/data  navidrome/data
```

### 5. write `docker-compose.override.yml`

if your existing stack has a reverse proxy (caddy, traefik, cloudflared) that
already routes `jellyfin:8096` or similar from another network, the new
`qanat-jellyfin` container needs to join that network with the same alias.
example:

```yaml
services:
  jellyfin:
    networks:
      default:
      legacy_proxy_network:
        aliases:
          - jellyfin

  navidrome:
    user: "1000:1000"  # match the host user that owns the data dir

networks:
  legacy_proxy_network:
    external: true
```

run `docker network ls` and `docker inspect <existing-container>` to find
the network name.

### 6. cutover

```bash
# stop the old containers (keep them around for rollback)
docker stop <old-aria2> <old-ariang> <old-metube> <old-jellyfin> <old-navidrome>

# bring up the qanat versions on the same data
docker compose --profile music up -d aria2 ariang metube jellyfin navidrome

# verify
docker compose ps
curl -fsI http://127.0.0.1:8096/health
curl -fsI http://127.0.0.1:6880
curl -s -X POST http://127.0.0.1:6800/jsonrpc \
  -d '{"jsonrpc":"2.0","method":"aria2.getVersion","params":["token:'"$ARIA2_RPC_SECRET"'"],"id":1}'
```

### 7. cleanup once you trust it

```bash
docker rm <old-aria2> <old-ariang> <old-metube> <old-jellyfin> <old-navidrome>
```

## rollback

if something breaks:

```bash
docker compose --profile music down
docker start <old-aria2> <old-ariang> <old-metube> <old-jellyfin> <old-navidrome>
```

old containers are still there because step 6 used `stop`, not `rm`.

## what we don't migrate

- **caddy** stays as the existing host reverse proxy. don't bring up
  `qanat-caddy` since 80/443 are already in use. add the new dns/routes to
  the existing caddy if you want public urls for the qanat services.
- **opencloud / homepage / collabora / keycloak** are net-new - decide
  whether you want them after the basic migration is stable.
