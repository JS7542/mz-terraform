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
  key_name   = "${var.tag_header}keypair"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${var.tag_header}keypair"
  }
}

resource "aws_instance" "std20_web_instance" {
  ami           = var.ami_id
  instance_type = "t3.nano"
  key_name      = aws_key_pair.std20_keypair.key_name

  # network 모듈에서 전달받은 첫 번째 Private subnet 사용
  subnet_id = var.subnet_id

  associate_public_ip_address = false

  vpc_security_group_ids = [
    var.web_sg_id,
    var.internal_ssh_sg_id
  ]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.tag_header}web-root-volume"
    }
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = 5
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.tag_header}web-data-volume"
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = var.user_data


  tags = {
    Name = "${var.tag_header}web-instance"
  }
}
