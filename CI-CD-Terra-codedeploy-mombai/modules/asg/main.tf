# =============================================================================
# 4. Auto Scaling Group
# - 3개 Private subnet에 배포
# - min 1 / desired 1 / max 2
# =============================================================================

resource "aws_lb_target_group" "std20_web_tg" {
  name     = "${var.tag_header}web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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
    Name = "${var.tag_header}web-tg"
  }
}

resource "aws_lb" "std20_external_alb" {
  name               = "${var.tag_header}external-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.external_alb_sg_id
  ]

  subnets = var.public_subnet_ids

  tags = {
    Name = "${var.tag_header}external-alb"
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
  name_prefix   = "${var.tag_header}web-lt-"
  image_id      = var.ami_id
  instance_type = "t3.nano"
  key_name      = var.key_name

  vpc_security_group_ids = [
    var.web_sg_id,
    var.internal_ssh_sg_id
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

  user_data = base64encode(var.user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.tag_header}web-asg-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.tag_header}web-asg-volume"
    }
  }


  tags = {
    Name = "${var.tag_header}web-lt"
  }
}

resource "aws_autoscaling_group" "std20_web_asg" {
  name             = "${var.tag_header}web-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 2

  vpc_zone_identifier = var.private_subnet_ids

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
    value               = "${var.tag_header}web-asg"
    propagate_at_launch = true
  }
}
