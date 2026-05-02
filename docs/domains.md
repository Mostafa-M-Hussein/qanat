# getting a domain

qanat needs a domain so caddy can issue tls certs and you can reach the
services from outside the vps. you don't need a fancy or expensive one.
here's the cheapest legitimate options i'd actually recommend.

## free (subdomain only, no money)

these give you a subdomain under someone else's domain. it works fine for
caddy + letsencrypt.

| service                          | example                       | notes                                                    |
|----------------------------------|-------------------------------|----------------------------------------------------------|
| **duckdns.org**                  | `myname.duckdns.org`          | dynamic dns, single subdomain, http-01 acme works        |
| **deSEC.io**                     | `myname.dedyn.io`             | dnssec by default, cleaner than duckdns                  |
| **afraid.org / FreeDNS**         | `myname.<some-public-domain>` | thousands of public domains to pick from                 |
| **github student pack**          | free `.me` for a year         | requires a `.edu` email                                  |

trade-offs: you only get one host (no `aria.example`, `tube.example`,
`watch.example`). that's a problem because qanat uses subdomains to route
different services. workaround: use **path routing** in caddy
(`example.duckdns.org/aria`, `example.duckdns.org/tube`) — the example
caddyfile in this repo assumes subdomains, you'd have to rewrite it.

## near-free ($1-3/year)

if you want real subdomain control, just buy a cheap tld:

| registrar                | tld(s)               | first-year price      |
|--------------------------|----------------------|-----------------------|
| **porkbun.com**          | `.xyz`, `.click`     | ~$1-2                 |
| **porkbun.com**          | `.digital`, `.fun`   | ~$3                   |
| **namecheap.com**        | `.xyz`, `.online`    | ~$1-3 (varies)        |
| **njal.la**              | `.com`, others       | ~$15 (privacy-first)  |

porkbun is what i'd pick for a hobby setup. cheapest legit registrar, free
whois privacy, free email forwarding, dnssec free.

## proper money ($10/year)

for a real `.com`:

| registrar               | price        | notes                                           |
|-------------------------|--------------|-------------------------------------------------|
| **cloudflare registrar**| at-cost ~$10 | no markup, requires cf account, dns is included |
| **porkbun.com**         | ~$10         | also fine, simpler ui                           |

avoid godaddy, hostgator, and any registrar with "domain auctions" — they
upsell aggressively and have hostile renewal pricing.

## what to do after buying

1. point your dns at the vps. add `A` records for each subdomain qanat uses:
   ```
   example.com           A  <vps-ip>     # homepage at the bare domain
   jellyfin.example.com  A  <vps-ip>
   aria.example.com      A  <vps-ip>
   metube.example.com    A  <vps-ip>
   cloud.example.com     A  <vps-ip>     # opencloud
   music.example.com     A  <vps-ip>     # navidrome (--profile music)
   collabora.example.com A  <vps-ip>     # collabora (--profile office)
   auth.example.com      A  <vps-ip>     # keycloak/authelia (--profile sso)
   ```
   or one wildcard:
   ```
   *.example.com  A  <vps-ip>
   ```
2. set `DOMAIN=example.com` and `ACME_EMAIL=you@example.com` in `.env`.
3. open ports 80, 443, 443/udp, and `ARIA2_BT_PORT` (default 6888) on your
   vps firewall.
4. `docker compose up -d`. caddy gets letsencrypt certs automatically on
   first run.

## why not cloudflare tunnel instead

if you don't want to open ports 80/443 on your vps, use the `--profile
tunnel` option and a cloudflare tunnel. then you only need a domain on
cloudflare's free dns plan ($10/yr for a `.com`, no extra cost for the
tunnel). caddy on the vps stays internal.

steps in [the cloudflare tunnel docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/),
short version:

1. create a tunnel in the cf zero-trust dashboard, copy the token.
2. paste into `TUNNEL_TOKEN` in `.env`.
3. `docker compose --profile tunnel up -d`.
4. add cname records in cf dns: `<sub>.example.com -> <tunnel-uuid>.cfargotunnel.com`.

## i recommend

- **just trying it out:** duckdns + path-routed caddy
- **hobby setup:** porkbun `.xyz` (~$1) + standard subdomain routing
- **serious setup:** cloudflare registrar `.com` + cf tunnel (no open ports)
