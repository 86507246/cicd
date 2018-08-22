#!/usr/bin/env bash 

source ./log.sh

function prepare_datadisks {
  log "Preparing data disks, striping, adding to fstab"
  ./vm-disk-utils-0.1.sh -b "/datadisks" -o "noatime,nodiratime,nodev,noexec,nosuid,nofail,barrier=0"
  log "Done preparing and configuring data disks"
}

function install_nfs {
    log "Configuring NFS server..."
    prepare_datadisks
}

function install_bbs {
    log "Configuration Bitbucket Server node..."
    prepare_datadisks
}

function install_unsupported {
    error "Unsupported installation option, abort"
}

case "$1" in
    nfs) install_nfs;;
    bbs) install_bbs;;
    *) install_unsupported;;
esac