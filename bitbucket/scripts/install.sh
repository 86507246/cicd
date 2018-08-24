#!/usr/bin/env bash 

source ./log.sh
source ./settings.sh

function ensure_jq {
    log "Making sure jq is installed. We need in the installation process"

    apt-get update
    apt-get install -y jq

    log "jq has been installed"
}

function ensure_atlhome {
    log "Making sure Atlassian home directory exists"

    mkdir -p "${ATL_HOME}"

    log "Atlassian home has been created"
}

function ensure_prerequisites {
    ensure_jq
    ensure_atlhome
}

function create_bb_group {
    log "Preparing a group for Bitbucket Server"

    groupadd \
        -g "${BBS_GID}" \ # hardcoded group id - neds to be the same on NFS server and client
        "${BBS_GROUP}"

    log "Bitbucket Server group has been created"
}

function create_bb_user {
    log "Preparing a user for Bitbucket Server"

    useradd -m -d "${BBS_HOME}" \ # create home directory as specified
        -s /bin/false \ # no login shell
        -u "${BBS_UID}" \ # hardcoded user id - needs to be the same on NFS server and client
        -g "${BBS_GID}" \ # same goes for group id
        "${BBS_USER}" # username

    log "Bitubkcet Server user has been created"
}

function create_bb_owner {
    log "Creating Bitbucket Server owner"

    create_bb_group
    create_bb_group

    log "Bitbucket Server owner is ready"
}


function prepare_datadisks {
  log "Preparing data disks, striping, adding to fstab"
  ./vm-disk-utils-0.1.sh -b "/datadisks" -o "noatime,nodiratime,nodev,noexec,nosuid,nofail,barrier=0"
  log "Done preparing and configuring data disks"
}

function nfs_install_server {
    log "Installing NFS server..."

    apt-get update
    apt-get install -y nfs-kernel-server

    log "NFS server has been installed"
}

function nfs_update_fstab {
    log "Updating fstab to bind [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}] at boot time."

    printf "\n${NFS_DISK_MOUNT}\t${NFS_SHARED_HOME}\tnone\tdefaults,bind\t0 0\n" >> /etc/fstab

    log "fstab has been updated"
}

function nfs_bind_directory {
    log "Binding [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}]"

    mount -B "${NFS_DISK_MOUNT}" "${NFS_SHARED_HOME}"

    log "Bound [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}]"
}

function nfs_prepare_shared_home {
    log "Preparing shared home directory"

    nfs_bind_directory
    nfs_update_fstab

    log "Shared home directory is ready!"
}

function nfs_configure_exports {
    cat <<EOT >> "/etc/exports"
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#

${NFS_SHARED_HOME} *(rw,subtree_check,root_squash)
EOT
}

function nfs_configure {
    log "Configuring NFS server..."

    nfs_configure_exports

    log "Restarting NFS server"
    systemctl restart nfs-server

    log "NFS server configuration has been completed!"
}

function install_common {
    ensure_prerequisites
    prepare_datadisks
    create_bb_owner
}

function install_nfs {
    log "Configuring NFS node..."

    install_common

    nfs_prepare_shared_home
    nfs_configure

    log "Done configuriong NFS node!"
}

function install_bbs {
    log "Configuration Bitbucket Server node..."
    
    install_common

    log "Done configuring Bitbucket Server node!"
}

function install_unsupported {
    error "Unsupported installation option, abort"
}

case "$1" in
    nfs) install_nfs;;
    bbs) install_bbs;;
    *) install_unsupported;;
esac