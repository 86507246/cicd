#!/usr/bin/env bash 

source ./log.sh
source ./settings.sh

function ensure_jq {
    log "Making sure jq is installed. We need it during the installation process"

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

    # Options:
    #  hardcoded group id - neds to be the same on NFS server and client
    #  group name
    groupadd \
        -g "${BBS_GID}" \
        "${BBS_GROUP}"

    log "Bitbucket Server group has been created"
}

function create_bb_user {
    log "Preparing a user for Bitbucket Server"

    # Options:
    #  create home directory as specified
    #  no login shell
    #  hardcoded user id - needs to be the same on NFS server and client
    #  same goes for group id
    #  a comment for the user
    #  username
    useradd -m -d "${BBS_HOME}" \
        -s /bin/bash \
        -u "${BBS_UID}" \
        -g "${BBS_GID}" \
        -c "Atlassian Bitbucket" \
        "${BBS_USER}" 

    log "Bitbucket Server user has been created"
}

function create_bb_owner {
    log "Creating Bitbucket Server owner"

    create_bb_group
    create_bb_user

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

function nfs_create_shared_home {
    log "Creating NFS shard home [directory=${NFS_SHARED_HOME}]"

    mkdir -p "${NFS_SHARED_HOME}"

    log "Done creating NFS shared home  [directory=${NFS_SHARED_HOME}]!"
}

function nfs_prepare_shared_home {
    log "Preparing shared home directory"

    nfs_create_shared_home
    nfs_bind_directory

    log "Updating [owner=${BBS_USER}":"${BBS_GROUP}] for [directory=${NFS_SHARED_HOME}]"
    chown "${BBS_USER}":"${BBS_GROUP}" "${NFS_SHARED_HOME}"

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

function bbs_install_nfs_client {
    log "Installing NFS client"

    apt-get update
    apt-get install -y nfs-common

    log "Done installing NFS client"
}

function bbs_create_shared_home {
    log "Creating Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]"

    mkdir -p "${BBS_SHARED_HOME}"
    chown "${BBS_USER}":"${BBS_GROUP}" "${BBS_SHARED_HOME}"

    log "Done creating Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]!"
}

function bbs_mount_shared_home {
    local msg_header="Mounting BitBucket Server shared home"
    local msg_source="[server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}]"
    local msg_target="[directory=${BBS_SHARED_HOME}]"
    local msg_opts="[options=${BBS_SHARED_HOME_MOUNT_OPTS}]"
    log "${msg_header} ${msg_source} to ${msg_target} with ${msg_opts}"

    mount -t nfs "${BBS_NFS_SERVER_IP}":"${NFS_SHARED_HOME}" -o "${BBS_SHARED_HOME_MOUNT_OPTS}" "${BBS_SHARED_HOME}"

    log "Done mounting BitBucket Server shared home [server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}] to [directory=${BBS_SHARED_HOME}]!"
}

function bbs_update_fstab {
    log "Updating /etc/fstab with shared home mount:"
    log "    from [server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}]"
    log "    to [directory=${BBS_SHARED_HOME}]"
    log "    with [options=${BBS_SHARED_HOME_MOUNT_OPTS}]"

    local source="${BBS_NFS_SERVER_IP}:${NFS_SHARED_HOME}"
    local target="${BBS_SHARED_HOME}"
    local opts="${BBS_SHARED_HOME_MOUNT_OPTS}"
    local type="nfs"

    printf "\n${source}\t${target}\t${type}\t${opts}\t0 0" >> /etc/fstab

    log "Done updating /etc/fstab!"
}

function bbs_configure_shared_home {
    log "Configuring Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]"

    bbs_create_shared_home
    bbs_mount_shared_home
    bbs_update_fstab

    log "Done configuring Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]!"
}

function bbs_download_installer {
    local base="${BBS_INSTALLER_BASE}"
    local bucket="${BBS_INSTALLER_BUCKET}"
    local path="${BBS_INSTALLER_PATH}"
    local version="${BBS_INSTALLER_VERSION}"
    local file="${BBS_INSTALLER_FILE}"

    local url="${base}/${bucket}/${path}/${version}/${file}"
    local target="installer"

    log "Downloading Bitbucket Server installer [base=${base}, bucket=${bucket}, path=${path}, version=${version}, file=${file}] from [url=${url}]"

    if ! curl -L -f --silent "${url}" \
       -o "${target}" 2>&1
    then
        error "Could not download Bitbucket Server installer from [url=${url}]"
        exit 1
    else
        log "Making Bitbucket Server installer executable..."
        chmod +x "${target}"
    fi

    log "Done downloading Bitbucket Server installer from [url=${url}]"
}

function bbs_prepare_installer_settings {
    local version="${BBS_INSTALLER_VERSION}"
    local home="${BBS_HOME}"

    log "Preparing installer configuration"

    cat <<EOT >> "${BBS_INSTALER_VARS}"
app.bitbucketHome=${home}
app.defaultInstallDir=/opt/atlassian/bitbucket/${version}
app.install.service$Boolean=true
executeLauncherAction$Boolean=true
httpPort=7990
installation.type=DATA_CENTER_INSTALL
launch.application$Boolean=true
sys.adminRights$Boolean=true
sys.languageId=en
EOT

    log "Done preparing installer configuration"
}

function bbs_run_installer {
    log "Running Bitbucket Server installer"

    bbs_prepare_installer_settings
    ./installer -q -varfile "${BBS_INSTALER_VARS}"

    log "Done running Bitbucket Server installer"
}

function bbs_stop {
    log "Stopping Bitbucket Server application..."

    /etc/init.d/atlbitbucket stop

    log "Bitbucket Server application has been stopped"
}

function bbs_start {
    log "Starting Bitbucket Server application..."

    /etc/init.d/atlbitbucket start

    log "Bitbucket Server application has been started"
}

function bbs_restart {
    log "Restarting Bitbucket Server application..."

    bbs_stop
    bbs_start

    log "Done restarting Bitbucket Server application"
}

function bbs_prepare_properties {
    log "Generging 'bitbucket.properties' configuration file"

    local dbhost="${SQL_HOST}"
    local dbuser="${SQL_USER}"
    local dbpass="${SQL_PASS}"

    local license="${BBS_LICENSE}"
    local baseUrl="${BBS_URL}"
    local adminUser="${BBS_ADMIN}"
    local adminPass="${BBS_PASS}"
    local adminName="${BBS_NAME}"
    local adminEmail="${BBS_EMAIL}"

    local file="${BBS_SHARED_HOME}/bitbucket.properties"

    cat <<EOT >> "${file}"
    jdbc.driver=com.microsoft.sqlserver.jdbc.SQLServerDriver
    jdbc.url=jdbc:sqlserver://${dbhost}.database.windows.net:1433;database=bitbucket-db;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;
    jdbc.user=${dbuser}
    jdbc.password=${dbpass}

    setup.license=${license}
    setup.displayName=Bitbucket
    setup.baseUrl=${baseUrl}
    setup.sysadmin.username=${adminUser}
    setup.sysadmin.password=${adminPass}
    setup.sysadmin.displayName=${adminName}
    setup.sysadmin.emailAddress=${adminEmail}
EOT
    chown "${BBS_USER}":"${BBS_GROUP}" "${file}"

    log "Done generating 'bitbucket.properties' configuration file"
}

function bbs_configure {
    log "Configuring Bitbucket Server application"

    bbs_prepare_properties
    bbs_restart

    log "Done configuring Bitbucket Server application"
}

function bbs_install {
    log "Downloading and running Bitbucket Server installer"

    bbs_download_installer
    bbs_run_installer

    log "Done downloading and running Bitbucket Server installer"
}

function install_common {
    ensure_prerequisites
    prepare_datadisks
    create_bb_owner
}

function install_nfs {
    log "Configuring NFS node..."

    install_common

    nfs_install_server
    nfs_prepare_shared_home
    nfs_configure

    log "Done configuriong NFS node!"
}

function install_bbs {
    log "Configuration Bitbucket Server node..."

    install_common
    bbs_install_nfs_client
    bbs_configure_shared_home

    bbs_install
    bbs_configure

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