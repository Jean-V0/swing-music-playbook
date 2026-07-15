#!/bin/bash
set -euo pipefail

# user_data is executed as root on Amazon Linux 2023.
mount_s3_rpm="$(mktemp --suffix=.rpm)"
curl -fsSL https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm -o "$mount_s3_rpm"
dnf install -y "$mount_s3_rpm"
rm -f "$mount_s3_rpm"

install -d -m 0755 /opt/musics

# fstab delegates lifecycle to Mountpoint and remounts it at every boot.
echo 's3://${s3_bucket}/ /opt/musics mount-s3 _netdev,nosuid,nodev,rw,allow-other,nofail 0 0' >> /etc/fstab
systemctl daemon-reload
mount -a
