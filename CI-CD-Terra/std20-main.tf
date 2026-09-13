# =============================================================================
# 1. Network
# =============================================================================

resource "aws_vpc" "std20_vpc" {
  cidr_block           = local.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.tag_header}vpc"
  }
}

# -----------------------------------------------------------------------------
# Subnet
# Public  : 10.0.1.0/24  ~ 10.0.3.0/24
# Private : 10.0.11.0/24 ~ 10.0.13.0/24
# Cluster : 10.0.21.0/24 ~ 10.0.23.0/24
# -----------------------------------------------------------------------------

resource "aws_subnet" "create_subnet" {
  for_each = local.subnet_map

  vpc_id            = aws_vpc.std20_vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.type == "public"

  # 요구사항: 모든 서브넷에서 시작 시 리소스 이름 DNS A 레코드 활성화
  enable_resource_name_dns_a_record_on_launch = true

  tags = merge(
    {
      Name = "${local.tag_header}${each.value.type}-${split("-", each.value.az)[length(split("-", each.value.az)) - 1]}-subnet"
      Type = each.value.type
      AZ   = each.value.az
    },

    each.value.type == "public" ? {
      "kubernetes.io/role/elb"                                      = "1"
      "kubernetes.io/cluster/${local.tag_header}eks-cluster"        = "shared"
    } : {},

    each.value.type == "cluster" ? {
      "kubernetes.io/role/internal-elb"                             = "1"
      "kubernetes.io/cluster/${local.tag_header}eks-cluster"        = "shared"
    } : {}
  )
}

# -----------------------------------------------------------------------------
# Internet Gateway / NAT Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "std20_igw" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${local.tag_header}igw"
  }
}

resource "aws_eip" "std20_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${local.tag_header}nat-eip"
  }
}

resource "aws_nat_gateway" "std20_nat_gw" {
  allocation_id = aws_eip.std20_nat_eip.id
  subnet_id     = aws_subnet.create_subnet["public-${local.azs[0]}"].id

  depends_on = [
    aws_internet_gateway.std20_igw
  ]

  tags = {
    Name = "${local.tag_header}nat-gw"
  }
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "std20_pub_rt" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${local.tag_header}public-rt"
  }
}

resource "aws_route_table" "std20_pri_rt" {
  for_each = {
    for key, subnet in local.subnet_map :
    key => subnet
    if subnet.type == "private"
  }

  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${local.tag_header}private-${split("-", each.value.az)[length(split("-", each.value.az)) - 1]}-rt"
  }
}

resource "aws_route_table" "std20_cluster_rt" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${local.tag_header}cluster-rt"
  }
}

resource "aws_route_table_association" "std20_pub_rt_assoc" {
  for_each = {
    for key, subnet in local.subnet_map :
    key => subnet
    if subnet.type == "public"
  }

  subnet_id      = aws_subnet.create_subnet[each.key].id
  route_table_id = aws_route_table.std20_pub_rt.id
}

resource "aws_route_table_association" "std20_pri_rt_assoc" {
  for_each = {
    for key, subnet in local.subnet_map :
    key => subnet
    if subnet.type == "private"
  }

  subnet_id      = aws_subnet.create_subnet[each.key].id
  route_table_id = aws_route_table.std20_pri_rt[each.key].id
}

resource "aws_route_table_association" "std20_cluster_rt_assoc" {
  for_each = {
    for key, subnet in local.subnet_map :
    key => subnet
    if subnet.type == "cluster"
  }

  subnet_id      = aws_subnet.create_subnet[each.key].id
  route_table_id = aws_route_table.std20_cluster_rt.id
}

resource "aws_route" "std20_pub_rt_internet_access" {
  route_table_id         = aws_route_table.std20_pub_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.std20_igw.id
}

resource "aws_route" "std20_pri_rt_nat_access" {
  for_each = aws_route_table.std20_pri_rt

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.std20_nat_gw.id
}

resource "aws_route" "std20_cluster_rt_nat_access" {
  route_table_id         = aws_route_table.std20_cluster_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.std20_nat_gw.id
}

# =============================================================================
# Security Groups
# =============================================================================

# -----------------------------------------------------------------------------
# NAT / Bastion - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_bastion_sg" {
  name        = "${local.tag_header}bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = aws_vpc.std20_vpc.id

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
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}bastion-sg"
  }
}

# -----------------------------------------------------------------------------
# SSH - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_internal_ssh_sg" {
  name        = "${local.tag_header}internal-ssh-sg"
  description = "Internal SSH through Bastion"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}internal-ssh-sg"
  }
}

# -----------------------------------------------------------------------------
# External ALB - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_external_alb_sg" {
  name        = "${local.tag_header}external-alb-sg"
  description = "External ALB Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}external-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# Web EC2 / ASG
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_web_sg" {
  name        = "${local.tag_header}web-sg"
  description = "Web Server Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}web-sg"
  }
}

# -----------------------------------------------------------------------------
# Internal ALB / HTTP/HTTPS - required
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_internal_alb_sg" {
  name        = "${local.tag_header}internal-alb-sg"
  description = "Internal ALB Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}internal-alb-sg"
  }
}

resource "aws_security_group" "std20_app_sg" {
  name        = "${local.tag_header}app-sg"
  description = "Application Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}app-sg"
  }
}

# -----------------------------------------------------------------------------
# Database Security Groups - optional
# 요구사항 표의 Source = VPC CIDR 적용
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_database_sg" {
  for_each = local.database_sg

  name        = "${local.tag_header}${each.value.name}"
  description = "Security group for ${each.key}"
  vpc_id      = aws_vpc.std20_vpc.id

  ingress {
    from_port   = each.value.port
    to_port     = each.value.port
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}${each.value.name}"
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster SG - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_eks_cluster_sg" {
  name        = "${local.tag_header}eks-cluster-sg"
  description = "EKS Cluster Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}eks-cluster-sg"
  }
}

# -----------------------------------------------------------------------------
# EKS Node SG - optional
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_eks_node_sg" {
  name        = "${local.tag_header}eks-node-sg"
  description = "EKS Worker Node Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}eks-node-sg"
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
  name        = "${local.tag_header}endpoint-sg"
  description = "VPC Interface Endpoint Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}endpoint-sg"
  }
}

# -----------------------------------------------------------------------------
# EFS SG
# -----------------------------------------------------------------------------

resource "aws_security_group" "std20_efs_sg" {
  name        = "${local.tag_header}efs-sg"
  description = "EFS NFS Security Group"
  vpc_id      = aws_vpc.std20_vpc.id

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
    Name = "${local.tag_header}efs-sg"
  }
}
