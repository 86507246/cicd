#!/bin/bash

apt-get update > /dev/null
apt-get install -y bonnie++ > /dev/null
apt-get install htop > /dev/null
(echo n; echo p; echo 1; echo; echo; echo w) | fdisk /dev/sdc > /dev/null
mkfs -t ext4 /dev/sdc1 > /dev/null
mkdir /datadisk > /dev/null
mount /dev/sdc1 /datadisk > /dev/null

bonnie++ -d /datadisk -r 2048 -u root -q > /datadisk/result.csv

cat /datadisk/result.csv