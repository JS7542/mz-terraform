# =============================================================================
# Security Groups
# =============================================================================

# -----------------------------------------------------------------------------
# NAT / Bastion - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_bastion_sg" {
  name        = "${var.tag_header}bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}bastion-sg"
  }
}

# -----------------------------------------------------------------------------
# SSH - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_internal_ssh_sg" {
  name        = "${var.tag_header}internal-ssh-sg"
  description = "Internal SSH through Bastion"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}internal-ssh-sg"
  }
}

# -----------------------------------------------------------------------------
# External ALB - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_external_alb_sg" {
  name        = "${var.tag_header}external-alb-sg"
  description = "External ALB Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}external-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# Web EC2 / ASG
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_web_sg" {
  name        = "${var.tag_header}web-sg"
  description = "Web Server Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}web-sg"
  }
}

# -----------------------------------------------------------------------------
# Internal ALB / HTTP/HTTPS - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_internal_alb_sg" {
  name        = "${var.tag_header}internal-alb-sg"
  description = "Internal ALB Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}internal-alb-sg"
  }
}

resource "aws_security_group" "std20_app_sg" {
  name        = "${var.tag_header}app-sg"
  description = "Application Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_internal_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}app-sg"
  }
}

# -----------------------------------------------------------------------------
# Database Security Groups - optional
# 요구사항 표의 Source = VPC CIDR 적용
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_database_sg" {
  for_each = local.database_sg

  name        = "${var.tag_header}${each.value.name}"
  description = "Security group for ${each.key}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = each.value.port
    to_port     = each.value.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}${each.value.name}"
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster SG - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_eks_cluster_sg" {
  name        = "${var.tag_header}eks-cluster-sg"
  description = "EKS Cluster Security Group"
  vpc_id      = var.vpc_id

  # 학습 환경: 외부 kubectl 접근 허용
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}eks-cluster-sg"
  }
}

# -----------------------------------------------------------------------------
# EKS Node SG - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_eks_node_sg" {
  name        = "${var.tag_header}eks-node-sg"
  description = "EKS Worker Node Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_external_alb_sg.id]
  }

  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.std20_eks_cluster_sg.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}eks-node-sg"
  }
}

# Node -> EKS API Server
# 별도 rule로 분리하여 Cluster SG <-> Node SG 생성 순환 참조 방지
resource "aws_vpc_security_group_ingress_rule" "std20_eks_cluster_from_node" {
  security_group_id = aws_security_group.std20_eks_cluster_sg.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.std20_eks_node_sg.id

  description = "Allow HTTPS from EKS Worker Nodes"
}

# -----------------------------------------------------------------------------
# VPC Endpoint SG
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_endpoint_sg" {
  name        = "${var.tag_header}endpoint-sg"
  description = "VPC Interface Endpoint Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}endpoint-sg"
  }
}

# -----------------------------------------------------------------------------
# EFS SG
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_efs_sg" {
  name        = "${var.tag_header}efs-sg"
  description = "EFS NFS Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"

    security_groups = [
      aws_security_group.std20_web_sg.id,
      aws_security_group.std20_app_sg.id,
      aws_security_group.std20_eks_node_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_header}efs-sg"
  }
}
