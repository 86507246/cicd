#!/usr/bin/env bash

source ./log.sh

function enable_port_forwarding {
    local target="${1}"
    local port="${2}"

    log "Enabling port forwarding for [port=${port}] traffic [target ip=${target}]"

    sysctl net.ipv4.ip_forward=1

    iptables -t nat -A PREROUTING -p tcp -i eth0 --dport "${port}" -j DNAT --to-destination "${target}"
    iptables -A FORWARD -i eth0 -p tcp -d "${target}" --dport "${port}" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    log "Done enabling port forwarding for [port=${port}] traffic [target ip=${target}]!"
}

function enable_nat {
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
}

if [ "x$1" == "x" ]; then
    log "Usage: enable_nat _app_gw_ip_ _git_lb_ip_"
else
    enable_nat
    enable_port_forwarding "$1" 80
    enable_port_forwarding "$1" 443
    enable_port_forwarding "$2" 7999
fi