#!/usr/bin/env bash

BBS_USER="bitbucket"
BBS_GROUP="bitbucket"
BBS_UID="7990"
BBS_GID="7990"
BBS_HOME="${ATL_HOME}/${BBS_USER}/home"
BBS_SHARED_HOME="${BBS_HOME}/shared_home"

BBS_SHARED_HOME_MOUNT_OPTS="lookupcache=pos,noatime,intr,rsize=32768,wsize=32768"