#!/usr/bin/env bash
set -euo pipefail

BBS_USER="atlbitbucket"
BBS_GROUP="atlbitbucket"
BBS_UID="9079"
BBS_GID="9079"
BBS_HOME="${ATL_HOME}/bitbucket"
BBS_SHARED_HOME="${BBS_HOME}/shared"

BBS_SHARED_HOME_MOUNT_OPTS="lookupcache=pos,noatime,intr,rsize=32768,wsize=32768,vers=3"

BBS_INSTALLER_BASE="${BBS_BASE:-https://product-downloads.atlassian.com}"
BBS_INSTALLER_BUCKET="${BBS_BUCKET:-software}"
BBS_INSTALLER_PATH="${BBS_PATH:-stash}"
BBS_INSTALLER_VERSION="${BBS_VERSION:-downloads}"
BBS_INSTALLER_FILE="${BBS_INSTALLER:-atlassian-bitbucket-6.0.0-linux-x64.bin}"
BBS_INSTALLER_VARS="installer.varfile"