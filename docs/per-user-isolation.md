# per-user isolation

this stack runs one user's services. if you want to share with friends or
study buddies, pick the isolation level that matches your trust model.

## tier 0 - jellyfin/navidrome users only

create users in the jellyfin and navidrome admin panels. they stream what
you've curated. no shell, no downloads, no file management.

- jellyfin: dashboard -> users -> add user
- navidrome: settings -> users

## tier 1 - ssh tunnel only, no shell

trust them with ariang and metube but not with shell access.

```bash
adduser --disabled-password friend1
mkdir -p /home/friend1/.ssh
echo 'ssh-ed25519 AAAA... friend1@laptop' > /home/friend1/.ssh/authorized_keys
chown -R friend1:friend1 /home/friend1/.ssh
chmod 700 /home/friend1/.ssh && chmod 600 /home/friend1/.ssh/authorized_keys
```

`/etc/ssh/sshd_config.d/friends.conf`:

```
Match User friend1,friend2,friend3
    ForceCommand /sbin/nologin
    AllowTcpForwarding yes
    PermitTunnel no
    X11Forwarding no
    PermitTTY no
    GatewayPorts no
    PermitOpen 127.0.0.1:6880 127.0.0.1:8081 127.0.0.1:8096
```

```bash
systemctl reload ssh
```

friend tunnels from their laptop:

```bash
ssh -N -L 6880:127.0.0.1:6880 -L 8081:127.0.0.1:8081 -L 8096:127.0.0.1:8096 friend1@vps
```

then visit `http://localhost:6880` etc.

shared downloads dir though - one person can saturate the uplink. shape
egress with `tc` if that becomes a problem (next section).

## tier 2 - bandwidth shaping per user

cap each friend's egress so no one starves the others.

```bash
IF=eth0

# 800 mbit total cap, 200 mbit per friend
tc qdisc add dev $IF root handle 1: htb default 30
tc class add dev $IF parent 1: classid 1:1 htb rate 800mbit ceil 800mbit
tc class add dev $IF parent 1:1 classid 1:10 htb rate 200mbit ceil 200mbit
tc class add dev $IF parent 1:1 classid 1:20 htb rate 200mbit ceil 200mbit
tc class add dev $IF parent 1:1 classid 1:30 htb rate 200mbit ceil 800mbit  # default

# map uid -> class
iptables -t mangle -A POSTROUTING -m owner --uid-owner friend1 -j CLASSIFY --set-class 1:10
iptables -t mangle -A POSTROUTING -m owner --uid-owner friend2 -j CLASSIFY --set-class 1:20
```

persist with iptables-persistent and a systemd unit for the tc rules.

## tier 3 - full incus/lxc containers

each friend gets their own isolated stack. disk quota, bandwidth quota,
their own sshd, their own everything. they can break their own setup
without breaking yours.

```bash
# debian 12 / ubuntu 24.04
apt update && apt install -y incus
incus admin init --minimal

incus launch images:debian/12 friend1
incus config device override friend1 root size=50GiB
incus config set friend1 limits.cpu=2 limits.memory=4GiB
incus config device set friend1 eth0 limits.egress=200Mbit
incus config device set friend1 eth0 limits.ingress=200Mbit
```

inside the container, install just what friend1 needs (their own qanat
stack, or just jellyfin, whatever). use caddy on the host to route
`friend1.${DOMAIN}` to the container's ip.

costs ~256mb ram per friend baseline. you become n times the sysadmin.

## what i'd actually do

- 2-3 close friends: tier 1 + a soft tc shaper
- study group of 5-15: tier 3 with a template container, copy it per friend
- public: don't
