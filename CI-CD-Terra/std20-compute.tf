# =============================================================================
# 2. EC2 Instance
# - t3.nano
# - Root 8 GiB
# - Additional 5 GiB
# - Web / SSH SG
# - EFS auto mount
# - Docker + Docker Compose
# - curl / unzip
# =============================================================================

resource "aws_key_pair" "std20_keypair" {
  key_name   = "${local.tag_header}keypair"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${local.tag_header}keypair"
  }
}

resource "aws_instance" "std20_web_instance" {
  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.nano"
  key_name      = aws_key_pair.std20_keypair.key_name

  # main.tf에서 생성한 첫 번째 Private subnet을 사용
  subnet_id = aws_subnet.create_subnet["private-${local.azs[0]}"].id

  associate_public_ip_address = false

  vpc_security_group_ids = [
    aws_security_group.std20_web_sg.id,
    aws_security_group.std20_internal_ssh_sg.id
  ]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.tag_header}web-root-volume"
    }
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 5
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${local.tag_header}web-data-volume"
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    efs_dns_name = aws_efs_file_system.std20_efs.dns_name
  })

  depends_on = [
    aws_efs_mount_target.std20_efs_mount_target
  ]

  tags = {
    Name = "${local.tag_header}web-instance"
  }
}
