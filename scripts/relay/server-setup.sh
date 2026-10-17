#!/bin/bash
# Riot-only WireGuard relay. Paste this whole file into the "Cloud-init script" box when creating
# an Ubuntu VM (Oracle Cloud / AWS / any provider). It runs once at first boot, as root.
# Result: /etc/wireguard/client.conf  (the PC config, fetched by Connect-RiotRelay.ps1)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# Some clouds (Google) re-run startup scripts on every boot; only set up once so the keys stay the same.
[ -f /etc/wireguard/ready ] && exit 0

apt-get update -y
apt-get install -y wireguard iptables curl

# Packet forwarding + low-latency socket settings
cat > /etc/sysctl.d/99-relay.conf <<'EOF'
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 16384
net.core.busy_poll = 50
net.core.busy_read = 50
EOF
sysctl --system >/dev/null

umask 077
cd /etc/wireguard
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee client.key | wg pubkey > client.pub

WAN=$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
PUBIP=$(curl -4 -s --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')

# Oracle's Ubuntu images ship iptables REJECT rules in INPUT and FORWARD; -I puts ours above them.
cat > wg0.conf <<EOF
[Interface]
Address = 10.66.0.1/24
ListenPort = 51820
PrivateKey = $(cat server.key)
MTU = 1412
PostUp   = iptables -I INPUT -p udp --dport 51820 -j ACCEPT; iptables -I FORWARD -i wg0 -j ACCEPT; iptables -I FORWARD -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport 51820 -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN -j MASQUERADE

[Peer]
PublicKey = $(cat client.pub)
AllowedIPs = 10.66.0.2/32
EOF

# Only Riot Games (AS6507) address space goes through the relay; everything else stays on the normal line.
RIOT="45.7.36.0/22, 138.0.12.0/22, 151.106.246.0/23, 151.106.248.0/22, 151.106.252.0/23, 151.106.254.0/24, 162.249.72.0/21, 45.250.208.0/22, 192.64.168.0/21, 185.40.64.0/22, 104.160.128.0/19, 103.240.224.0/22, 192.207.0.0/24, 43.229.64.0/22, 103.219.128.0/22"

cat > client.conf <<EOF
[Interface]
PrivateKey = $(cat client.key)
Address = 10.66.0.2/32
MTU = 1412

[Peer]
PublicKey = $(cat server.pub)
Endpoint = $PUBIP:51820
AllowedIPs = 10.66.0.0/24, $RIOT
PersistentKeepalive = 25
EOF
chmod 644 client.conf   # readable by the ubuntu user over ssh

systemctl enable --now wg-quick@wg0

# No relay->Riyadh estimate here: Riot's game servers don't answer probes and no public endpoint
# reliably stands in for them. VALORANT's own logged ping (Check-ValorantPing.ps1) is the real test.
echo "relay ready" > ready
chmod 644 ready
