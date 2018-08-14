#!/usr/bin/env bash 

source ./log.sh

function prepare_datadisks {
  log prepare_datadisks "Preparing data disks, striping, adding to fstab"
  ./vm-disk-utils-0.1.sh -b "/datadisks" -o "noatime,nodiratime,nodev,noexec,nosuid,nofail,barrier=0"
  log prepare_datadisks "Done preparing and configuring data disks"
}

prepare_datadisks