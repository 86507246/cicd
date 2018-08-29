#!/usr/bin/env bash

source ./log.sh

SOURCE_PORT="80"
TARGET_PORT="80"

function enable_port_forwarding {
    local target = "${1}"

    log "Enabling port forwarding for HTTP traffic [target ip=${target}]"

    sysctl net.ipv4.ip_forward=1


    iptables -t nat -A PREROUTING -p tcp -i eth0 --dport "${TARGET_PORT}" -j DNAT --to-destination "${target}"
    iptables -A FORWARD -i eth0 -p tcp -d "${target}"--dport "${TARGET_PORT}" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    iptables -t nat -A POSTROUTING -j MASQUERADE

    log "Done enabling port forwarding for HTTP traffic [target ip=${target}]!"
}

if [ "x$1" == "x" ]; then
    log "Usage: enable_nat _target_ip_"
else
    enable_port_forwarding "$1"
fi