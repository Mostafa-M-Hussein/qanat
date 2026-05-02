# sso

`--profile sso` brings up keycloak + a postgres for it + oauth2-proxy as a
forward-auth gate. caddy then asks oauth2-proxy "is this user logged in?"
before letting traffic hit the gated services.

three layers, each with its own login model:

| service       | how it gets sso                                          |
|---------------|----------------------------------------------------------|
| aria, metube  | caddy `forward_auth` to oauth2-proxy. no per-app login.  |
| navidrome     | same as above (subsonic clients still need an app pw)    |
| jellyfin      | install the jellyfin sso plugin pointing at keycloak     |
| opencloud     | full oidc rewrite of opencloud env. one-way migration.   |

## bringing up keycloak

1. add dns records:
   ```
   auth.example.com       A  <vps-ip>
   auth-gate.example.com  A  <vps-ip>
   ```
2. fill in `.env`:
   ```
   KEYCLOAK_ADMIN_PASSWORD=...
   KC_DB_PASSWORD=...
   OAUTH2_PROXY_COOKIE_SECRET=$(openssl rand -base64 32 | tr -- '+/' '-_' | head -c 32)
   ```
3. `docker compose --profile sso up -d keycloak-postgres keycloak`
4. open `https://auth.example.com`, log in as `kcadmin` (or whatever you set
   in `KEYCLOAK_ADMIN`).

## creating the qanat realm

in the keycloak admin ui:

1. top-left dropdown -> create realm. name: `qanat`. create.
2. clients -> create client.
   - client id: `qanat-gate`
   - client authentication: ON
   - authentication flow: standard flow
   - valid redirect uris: `https://auth-gate.example.com/oauth2/callback`
   - web origins: `+`
   - save
3. clients -> qanat-gate -> credentials tab. copy the client secret into
   `OAUTH2_PROXY_CLIENT_SECRET` in `.env`.
4. realm settings -> general -> require ssl: external requests.
5. users -> add user. set username, email, first/last name. save.
   then credentials tab -> set password (uncheck "temporary"). save.

```bash
docker compose --profile sso up -d oauth2-proxy
docker compose restart caddy
```

## gating a service

edit `caddy/Caddyfile`. in the `aria.{$DOMAIN}` and `metube.{$DOMAIN}`
blocks, comment out `basic_auth { ... }` and uncomment `import sso_gate`.

```
aria.{$DOMAIN} {
    import sso_gate
    # basic_auth {
    #     {$BASIC_AUTH_USER} {$BASIC_AUTH_HASH}
    # }
    reverse_proxy ariang:6880
    @rpc path /jsonrpc /jsonrpc/*
    handle @rpc {
        reverse_proxy aria2:6800
    }
}
```

reload caddy: `docker compose restart caddy`. now hitting `aria.example.com`
redirects to keycloak; after login you land back on aria.

## jellyfin

caddy can't gate jellyfin the same way - the desktop/mobile/tv apps
authenticate against jellyfin's own api, not the browser. instead use the
jellyfin sso plugin.

1. jellyfin -> dashboard -> plugins -> repositories -> add:
   ```
   https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json
   ```
2. plugins -> catalog -> SSO authentication -> install -> restart jellyfin.
3. plugins -> SSO authentication -> add provider:
   - oid endpoint: `https://auth.example.com/realms/qanat/.well-known/openid-configuration`
   - client id / secret: same as oauth2-proxy or a fresh keycloak client
   - role claim: `realm_access.roles`
   - admin role: `jellyfin-admin` (create in keycloak realm roles)

users in keycloak now log into jellyfin via the "SSO" button on its login page.

## opencloud

opencloud has native oidc. switching it to keycloak is a bigger move - the
built-in IDM/IDP services are disabled and replaced with an external ldap.
follow the upstream guide if you want this:

  https://github.com/opencloud-eu/opencloud-compose/blob/main/idm/ldap-keycloak.yml

short version of env changes (apply to opencloud service):

```
OC_EXCLUDE_RUN_SERVICES: idm,idp
OC_LDAP_URI: ldaps://ldap-server:1636
OC_LDAP_BIND_DN: cn=admin,dc=qanat,dc=local
OC_LDAP_BIND_PASSWORD: ${LDAP_BIND_PASSWORD}
PROXY_AUTOPROVISION_ACCOUNTS: "false"
PROXY_ROLE_ASSIGNMENT_DRIVER: oidc
OC_OIDC_ISSUER: https://auth.example.com/realms/qanat
WEB_OIDC_CLIENT_ID: opencloud-web
```

migration is one-way - your existing opencloud admin user becomes
inaccessible after the switch unless you recreate it in keycloak with the
same uuid. only do this on a fresh install or after backing up
`opencloud/data`.

## why this is overkill for 3 friends

keycloak is ~600mb ram, full realm management, postgres-backed. for a small
group `--profile authelia` is the right call.

## authelia (the light option)

```bash
./setup.sh   # generates JWT_SECRET, SESSION_SECRET, STORAGE_ENCRYPTION_KEY
             # also creates config/authelia/users_database.yml from the example
```

set the admin password hash:

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'your-pw'
```

paste the resulting `$argon2id$...` string into the `password:` field of
`config/authelia/users_database.yml`. while you're there, fix the email and
add more users below the first.

bring it up and add dns:

```
auth.example.com  A  <vps-ip>
```

```bash
docker compose --profile authelia up -d
```

gate a site - same pattern as keycloak, just a different snippet:

```
aria.{$DOMAIN} {
    import authelia_gate
    reverse_proxy ariang:6880
    @rpc path /jsonrpc /jsonrpc/*
    handle @rpc { reverse_proxy aria2:6800 }
}
```

then `docker compose restart caddy`. browser hits `aria.example.com`,
authelia redirects to login, after login you land back.

note: authelia and keycloak both want `auth.{$DOMAIN}`. pick one. if you go
authelia, edit the `auth.{$DOMAIN}` block in `caddy/Caddyfile` to
`reverse_proxy authelia:9091`.
