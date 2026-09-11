# # =================================================================================
# # EC2 + EFS 구성
# #
# # EC2
# # - Ubuntu 24.04
# # - Instance Type : t3.nano
# # - Root Volume   : 8 GiB gp3
# # - Data Volume   : 5 GiB gp3
# # - Private Subnet
# # - Web / SSH Security Group
# #
# # User Data
# # - 추가 EBS 자동 포맷 및 /mnt/data 마운트
# # - EFS 자동 마운트 (/mnt/efs)
# # - Docker 설치
# # - Docker Compose 설치
# # - AWS CLI v2 설치
# # - curl / unzip 설치
# # - 1 GiB Swap 구성
# # =================================================================================






# # =================================================================================
# # 3. EFS File System
# # =================================================================================

# resource "aws_efs_file_system" "std20_efs" {
#     creation_token = "${local.tag_header}efs"

#     encrypted = true

#     performance_mode = "generalPurpose"
#     throughput_mode  = "bursting"

#     tags = {
#         Name = "${local.tag_header}efs"
#     }
# }


# # =================================================================================
# # 4. EFS Mount Target
# #
# # Private Subnet마다 Mount Target 생성
# #
# # 예:
# # Private 1a -> EFS Mount Target
# # Private 1b -> EFS Mount Target
# # Private 1c -> EFS Mount Target
# # =================================================================================

# resource "aws_efs_mount_target" "std20_efs_mount_target" {
#     for_each = aws_subnet.std20_pri_subnet

#     file_system_id = aws_efs_file_system.std20_efs.id
#     subnet_id      = each.value.id

#     security_groups = [
#         aws_security_group.std20_efs_sg.id
#     ]
# }


# # =================================================================================
# # 5. EC2 Instance
# # =================================================================================

# resource "aws_instance" "std20_web_instance" {
#     ami           = data.aws_ami.std20_ubuntu_ami.id
#     instance_type = "t3.nano"

#     # =========================================================================
#     # Network
#     #
#     # 첫 번째 AZ의 Private Subnet 사용
#     # =========================================================================

#     subnet_id = aws_subnet.std20_pri_subnet[local.az_names[0]].id

#     associate_public_ip_address = false


#     # =========================================================================
#     # Security Group
#     #
#     # Web
#     # SSH(Bastion 경유)
#     # =========================================================================

#     vpc_security_group_ids = [
#         aws_security_group.std20_web_sg.id,
#         aws_security_group.std20_internal_ssh_sg.id
#     ]


#     # =========================================================================
#     # SSH Key
#     #
#     # 기존 Key Pair가 있을 경우 사용
#     # =========================================================================

#     # key_name = "std20-key"


#     # =========================================================================
#     # Root Volume
#     # 8 GiB gp3
#     # =========================================================================

#     root_block_device {
#         volume_size           = 8
#         volume_type           = "gp3"
#         encrypted             = true
#         delete_on_termination = true

#         tags = {
#             Name = "${local.tag_header}web-root-volume"
#         }
#     }


#     # =========================================================================
#     # 추가 EBS Volume
#     # 5 GiB gp3
#     #
#     # User Data에서 /mnt/data로 자동 마운트
#     # =========================================================================

#     ebs_block_device {
#         device_name           = "/dev/sdf"
#         volume_size           = 5
#         volume_type           = "gp3"
#         encrypted             = true
#         delete_on_termination = true

#         tags = {
#             Name = "${local.tag_header}web-data-volume"
#         }
#     }


#     # =========================================================================
#     # IMDSv2
#     # =========================================================================

#     metadata_options {
#         http_endpoint = "enabled"
#         http_tokens   = "required"
#     }


#     # =========================================================================
#     # User Data
#     # =========================================================================

#     user_data = <<-EOF
#         #!/bin/bash

#         # =====================================================================
#         # 기본 환경 설정
#         # =====================================================================

#         export DEBIAN_FRONTEND=noninteractive

#         apt-get update -y

#         apt-get install -y \
#             curl \
#             unzip \
#             nfs-common \
#             docker.io \
#             docker-compose-v2


#         # =====================================================================
#         # AWS CLI v2 설치
#         # =====================================================================

#         cd /tmp

#         curl -fsSL \
#             "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
#             -o awscliv2.zip

#         unzip -q awscliv2.zip

#         ./aws/install

#         rm -rf \
#             /tmp/aws \
#             /tmp/awscliv2.zip


#         # =====================================================================
#         # Docker 설정
#         # =====================================================================

#         systemctl enable docker
#         systemctl start docker

#         usermod -aG docker ubuntu


#         # =====================================================================
#         # t3.nano 메모리 보완
#         #
#         # t3.nano는 메모리가 작기 때문에
#         # Docker 실행 안정성을 위해 1 GiB Swap 구성
#         # =====================================================================

#         if [ ! -f /swapfile ]; then

#             fallocate -l 1G /swapfile

#             chmod 600 /swapfile

#             mkswap /swapfile

#             swapon /swapfile

#             echo "/swapfile none swap sw 0 0" >> /etc/fstab

#         fi


#         # =====================================================================
#         # 추가 5 GiB EBS Volume 설정
#         #
#         # Nitro 계열에서는 /dev/sdf가 실제 OS에서
#         # /dev/nvme1n1 등의 이름으로 표시될 수 있으므로
#         # 5 GiB 디스크를 검색해서 사용
#         # =====================================================================

#         mkdir -p /mnt/data


#         # Volume이 OS에 나타날 때까지 대기

#         for i in {1..30}
#         do

#             DATA_DEVICE=$(lsblk -b -dn -o NAME,SIZE,TYPE \
#                 | awk '$2 == 5368709120 && $3 == "disk" {print "/dev/"$1; exit}')

#             if [ -n "$DATA_DEVICE" ]; then
#                 break
#             fi

#             sleep 2

#         done


#         # Volume을 찾은 경우

#         if [ -n "$DATA_DEVICE" ]; then

#             # 파일시스템이 없으면 ext4 생성

#             if ! blkid "$DATA_DEVICE" > /dev/null 2>&1; then
#                 mkfs.ext4 -F "$DATA_DEVICE"
#             fi


#             # UUID 확인

#             DATA_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")


#             # 재부팅 후 자동 마운트

#             if ! grep -q "UUID=$DATA_UUID" /etc/fstab; then

#                 echo \
#                     "UUID=$DATA_UUID /mnt/data ext4 defaults,nofail 0 2" \
#                     >> /etc/fstab

#             fi


#             mount -a

#             chown ubuntu:ubuntu /mnt/data

#         fi


#         # =====================================================================
#         # EFS Mount
#         # =====================================================================

#         mkdir -p /mnt/efs


#         # EFS DNS가 준비될 때까지 잠시 대기

#         for i in {1..30}
#         do

#             if getent hosts ${aws_efs_file_system.std20_efs.dns_name} > /dev/null 2>&1; then
#                 break
#             fi

#             sleep 2

#         done


#         # ---------------------------------------------------------------------
#         # /etc/fstab 등록
#         #
#         # 재부팅 후 EFS 자동 마운트
#         # ---------------------------------------------------------------------

#         if ! grep -q "${aws_efs_file_system.std20_efs.dns_name}" /etc/fstab; then

#             echo \
#                 "${aws_efs_file_system.std20_efs.dns_name}:/ /mnt/efs nfs4 defaults,_netdev,nofail,nfsvers=4.1 0 0" \
#                 >> /etc/fstab

#         fi


#         # ---------------------------------------------------------------------
#         # EFS Mount
#         # ---------------------------------------------------------------------

#         mount -a


#         # =====================================================================
#         # 설치 확인 로그
#         # =====================================================================

#         echo "============================================================"
#         echo " EC2 Initialization Complete"
#         echo "============================================================"

#         echo ""
#         echo "===== AWS CLI ====="
#         aws --version

#         echo ""
#         echo "===== Docker ====="
#         docker --version

#         echo ""
#         echo "===== Docker Compose ====="
#         docker compose version

#         echo ""
#         echo "===== Disk ====="
#         df -h

#         echo ""
#         echo "===== Block Device ====="
#         lsblk

#         echo ""
#         echo "===== Mount ====="
#         mount | grep -E "/mnt/data|/mnt/efs"

#         echo ""
#         echo "===== Swap ====="
#         swapon --show

#         echo "============================================================"

#     EOF


#     # =========================================================================
#     # EFS Mount Target가 먼저 생성된 이후 EC2 생성
#     # =========================================================================

#     depends_on = [
#         aws_efs_mount_target.std20_efs_mount_target
#     ]


#     tags = {
#         Name = "${local.tag_header}web-instance"
#     }
# }