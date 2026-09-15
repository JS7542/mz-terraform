#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  curl \
  unzip \
  nfs-common \
  docker.io \
  docker-compose-v2

systemctl enable --now docker
usermod -aG docker ubuntu || true

# -----------------------------------------------------------------------------
# 5 GiB 추가 EBS -> /mnt/data
# Nitro 인스턴스에서는 /dev/sdf가 /dev/nvme* 이름으로 표시될 수 있으므로
# 크기로 검색한다.
# -----------------------------------------------------------------------------

mkdir -p /mnt/data

DATA_DEVICE=""

for i in $(seq 1 30); do
  DATA_DEVICE=$(lsblk -b -dn -o NAME,SIZE,TYPE \
    | awk '$2 == 5368709120 && $3 == "disk" {print "/dev/"$1; exit}')

  if [ -n "$DATA_DEVICE" ]; then
    break
  fi

  sleep 2
done

if [ -n "$DATA_DEVICE" ]; then
  if ! blkid "$DATA_DEVICE" >/dev/null 2>&1; then
    mkfs.ext4 -F "$DATA_DEVICE"
  fi

  DATA_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")

  if ! grep -q "UUID=$DATA_UUID" /etc/fstab; then
    echo "UUID=$DATA_UUID /mnt/data ext4 defaults,nofail 0 2" >> /etc/fstab
  fi

  mount -a
  chown ubuntu:ubuntu /mnt/data
fi

# -----------------------------------------------------------------------------
# EFS -> /mnt/efs
# -----------------------------------------------------------------------------

mkdir -p /mnt/efs

for i in $(seq 1 60); do
  if getent hosts ${efs_dns_name} >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

if ! grep -q "${efs_dns_name}" /etc/fstab; then
  echo "${efs_dns_name}:/ /mnt/efs nfs4 defaults,_netdev,nofail,nfsvers=4.1 0 0" >> /etc/fstab
fi

mount -a

# -----------------------------------------------------------------------------
# Docker 동작 확인용 Nginx 컨테이너
# -----------------------------------------------------------------------------

docker rm -f std20-web >/dev/null 2>&1 || true
docker run -d \
  --name std20-web \
  --restart unless-stopped \
  -p 80:80 \
  nginx:alpine

echo "EC2 initialization complete"
df -h
lsblk
docker --version
docker compose version
