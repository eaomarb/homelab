#!/bin/bash

# 1. Selective cleanup
iptables -F INPUT
iptables -F DOCKER-USER 2>/dev/null

# 2. Default policies
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

# 3. INPUT (host access)
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow Docker containers (NPM) to reach the ntfy port on the host
iptables -A INPUT -s 172.18.0.0/16 -p tcp --dport 8082 -j ACCEPT
iptables -A INPUT -s 172.18.0.0/16 -p tcp --dport 8083 -j ACCEPT

iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -s 192.168.1.195 -j ACCEPT
iptables -A INPUT -s 192.168.1.58 -j ACCEPT
iptables -A INPUT -s 10.0.0.2 -j ACCEPT
iptables -A INPUT -s 10.0.0.3 -j ACCEPT
iptables -A INPUT -s 10.0.0.4 -j ACCEPT

# Restrict 10.0.0.5 on the host (ping, Jellyfin and Jellyseerr only)
iptables -A INPUT -s 10.0.0.5 -p icmp -j ACCEPT
iptables -A INPUT -s 10.0.0.5 -p tcp -m multiport --dports 8096,5055 -j ACCEPT

# 4. DOCKER-USER (filtering container access)
# Allow replies to traffic requested by the containers
iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow full internal communication between containers (172.18.0.0/16 network)
iptables -A DOCKER-USER -s 172.18.0.0/16 -d 172.18.0.0/16 -j ACCEPT

# Allow containers out to the internet
iptables -A DOCKER-USER -i br-+ -o eno1 -j ACCEPT

# WHITELIST: who can reach the containers from outside
iptables -A DOCKER-USER -s 192.168.1.195 -j ACCEPT
iptables -A DOCKER-USER -s 192.168.1.58 -j ACCEPT
iptables -A DOCKER-USER -s 10.0.0.2 -j ACCEPT
iptables -A DOCKER-USER -s 10.0.0.3 -j ACCEPT
iptables -A DOCKER-USER -s 10.0.0.4 -j ACCEPT

# Restrict 10.0.0.5 on containers (Jellyfin and Jellyseerr only)
iptables -A DOCKER-USER -s 10.0.0.5 -p tcp -m multiport --dports 8096,5055 -j ACCEPT

# Drop everything not on the whitelist
iptables -A DOCKER-USER -j DROP

# 5. FORWARD (VPN traffic to the internet)
# Allow VPN traffic out through eno1
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -i wg0 -o eno1 -j ACCEPT

# 6. NAT (masquerade for the VPN)
# Only add it if it does not exist, to avoid duplicates
iptables -t nat -C POSTROUTING -s 10.0.0.0/24 -o eno1 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eno1 -j MASQUERADE
