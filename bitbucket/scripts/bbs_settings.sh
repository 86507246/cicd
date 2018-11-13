#!/usr/bin/env bash

BBS_USER="atlbitbucket"
BBS_GROUP="atlbitbucket"
BBS_UID="9079"
BBS_GID="9079"
BBS_HOME="${ATL_HOME}/bitbucket"
BBS_SHARED_HOME="${BBS_HOME}/shared"

BBS_SHARED_HOME_MOUNT_OPTS="lookupcache=pos,noatime,intr,rsize=32768,wsize=32768,nfsvers=3"

BBS_INSTALLER_BASE="${BBS_BASE:-https://s3.amazonaws.com}"
BBS_INSTALLER_BUCKET="${BBS_BUCKET:-atlassian-software}"
BBS_INSTALLER_PATH="${BBS_PATH:-releases/bitbucket}"
BBS_INSTALLER_VERSION="${BBS_VERSION:-latest}"
BBS_INSTALLER_FILE="${BBS_INSTALLER:-atlassian-bitbucket-linux-x64.bin}"
BBS_INSTALER_VARS="installer.varfile"

# NFS_SERVER_IP comes from outside
BBS_NFS_SERVER_IP="${NFS_SERVER_IP}"