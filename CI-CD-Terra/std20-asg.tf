# =============================================================================
# 4. Auto Scaling Group
# - 3개 Private subnet에 배포
# - min 1 / desired 1 / max 2
# =============================================================================

resource "aws_lb_target_group" "std20_web_tg" {
  name     = "${local.tag_header}web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.std20_vpc.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }

  tags = {
    Name = "${local.tag_header}web-tg"
  }
}

resource "aws_lb" "std20_external_alb" {
  name               = "${local.tag_header}external-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.std20_external_alb_sg.id
  ]

  subnets = [
    for az in local.azs :
    aws_subnet.create_subnet["public-${az}"].id
  ]

  tags = {
    Name = "${local.tag_header}external-alb"
  }
}

resource "aws_lb_listener" "std20_external_alb_http" {
  load_balancer_arn = aws_lb.std20_external_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.std20_web_tg.arn
  }
}

resource "aws_launch_template" "std20_web_lt" {
  name_prefix   = "${local.tag_header}web-lt-"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.nano"
  key_name      = aws_key_pair.std20_keypair.key_name

  vpc_security_group_ids = [
    aws_security_group.std20_web_sg.id,
    aws_security_group.std20_internal_ssh_sg.id
  ]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size           = 5
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    efs_dns_name = aws_efs_file_system.std20_efs.dns_name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.tag_header}web-asg-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${local.tag_header}web-asg-volume"
    }
  }

  depends_on = [
    aws_efs_mount_target.std20_efs_mount_target
  ]

  tags = {
    Name = "${local.tag_header}web-lt"
  }
}

resource "aws_autoscaling_group" "std20_web_asg" {
  name             = "${local.tag_header}web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 2

  vpc_zone_identifier = [
    for az in local.azs :
    aws_subnet.create_subnet["private-${az}"].id
  ]

  target_group_arns = [
    aws_lb_target_group.std20_web_tg.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.std20_web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.tag_header}web-asg"
    propagate_at_launch = true
  }
}
