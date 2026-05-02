# architecture

## the vps-as-buffer pattern

```
                  egypt / mena last-mile (slow, unreliable)
                                  │
                                  │  ssh tunnel / tls / cf tunnel
                                  │  (one persistent low-bw pipe)
                                  ▼
        ┌─────────────────────────────────────────────────┐
        │ eu/us vps (gigabit symmetric, well-peered)      │
        │                                                 │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
        │  │ aria2    │  │ metube   │  │ jellyfin │      │
        │  │ (http/bt)│  │ (yt-dlp) │  │ (stream) │      │
        │  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
        │       └─────────┬───┴─────────────┘            │
        │                 ▼                              │
        │           shared volume                        │
        │           (downloads + media)                  │
        │                                                 │
        │  ┌──────────────────────┐                       │
        │  │ caddy reverse proxy  │ ← tls                 │
        │  └──────────────────────┘                       │
        └─────────────────┬───────────────────────────────┘
                          ▼
                  public internet
              (gigabit, low latency)
```

## why each piece

**aria2-pro.** splits a single http file into 16+ parallel ranges. handles
bittorrent too, which matters for big iso/dataset distribution. the rpc
api is what lets ariang drive it from the browser.

**ariang.** static html ui that talks to aria2's rpc. no backend of its own.

**metube.** wrapper around yt-dlp (1000+ sites - youtube, vimeo, twitch
vods, bilibili, ig, x). adds a queue ui, supports cookies (age-gate /
member-only), takes arbitrary yt-dlp options as json which is how we route
it through warp.

**jellyfin.** the playback half. once aria2 or metube finish a file into
`MEDIA_DIR`, jellyfin's library scanner picks it up. transcoding works but
on a vps with no gpu it'll melt the cpu - force direct-play.

**navidrome.** subsonic-api music streamer for the same files.

**caddy.** tls terminator with auto letsencrypt. cleaner than nginx for this
use case - renewal, ocsp, http/3 just work.

**cloudflared.** outbound persistent tunnel from the vps to cf's edge. cf
proxies traffic in. means you don't need 80/443 open at all.

**warp.** cloudflare's free warp service exposed as a local socks5. youtube
and a few other big platforms aggressively block known datacenter ips;
routing yt-dlp through warp makes you look like a residential cf customer.

## network topology

```
qanat (single user-defined bridge)
│
├─ aria2          127.0.0.1:6800  + 6888/tcp+udp public (bt)
├─ ariang         127.0.0.1:6880
├─ metube         127.0.0.1:8081
├─ jellyfin      127.0.0.1:8096
├─ navidrome      127.0.0.1:4533    [profile: music]
├─ warp           127.0.0.1:40000   [profile: warp]
├─ cloudflared    no ports          [profile: tunnel]
└─ caddy          0.0.0.0:80, :443
```

loopback binding is deliberate. anything reaching a service has to come
through caddy (tls + auth) or an ssh / cf tunnel. nothing leaks if a
service has a cve.

## a typical download

```
1. user opens https://aria.example.com
   -> caddy -> basic auth -> ariang
2. user pastes a magnet
3. ariang calls aria2 rpc at /jsonrpc -> aria2 starts torrent
4. aria2 writes chunks into ./files/  (= /downloads inside the container)
5. ./files/ is bind-mounted into jellyfin too (as part of /media)
6. jellyfin's library scan picks up the new file
7. user opens https://jellyfin.example.com -> plays
   (direct-play if codec is mp4/h264/aac, otherwise transcoded)
```

## failure modes

| failure                          | effect                          | mitigation                                              |
|----------------------------------|----------------------------------|---------------------------------------------------------|
| vps disk fills                   | downloads fail                   | cron `find ./files -mtime +30 -delete`, monitor df      |
| youtube ip-blocks the vps        | metube fails                     | enable `--profile warp`                                 |
| cf tunnel disconnects            | public access dies               | open 80/443 as fallback, set dns a records as backup    |
| jellyfin transcode pegs cpu      | playback laggy / timeouts        | disable transcoding, force direct-play codecs           |
| bt port not reachable            | low peer counts                  | open ARIA2_BT_PORT on host firewall                     |
| letsencrypt rate-limits domain   | tls expires                      | use staging endpoint while testing                      |
