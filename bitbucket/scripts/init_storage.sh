#!/bin/bash

(echo n; echo p; echo 1; echo; echo; echo w) | fdisk /dev/sdc > /dev/null
mkfs -t ext4 /dev/sdc1 > /dev/null
mkdir /datadisk > /dev/null
mount /dev/sdc1 /datadisk > /dev/null