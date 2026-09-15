# =============================================================================
# 1. Network
# =============================================================================

resource "aws_vpc" "std20_vpc" {
  cidr_block           = local.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.tag_header}vpc"
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
      Name = "${var.tag_header}${each.value.type}-${split("-", each.value.az)[length(split("-", each.value.az)) - 1]}-subnet"
      Type = each.value.type
      AZ   = each.value.az
    },

    each.value.type == "public" ? {
      "kubernetes.io/role/elb"                                      = "1"
      "kubernetes.io/cluster/${var.tag_header}eks-cluster"        = "shared"
    } : {},

    each.value.type == "cluster" ? {
      "kubernetes.io/role/internal-elb"                             = "1"
      "kubernetes.io/cluster/${var.tag_header}eks-cluster"        = "shared"
    } : {}
  )
}

# -----------------------------------------------------------------------------
# Internet Gateway / NAT Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "std20_igw" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${var.tag_header}igw"
  }
}

resource "aws_eip" "std20_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.tag_header}nat-eip"
  }
}

resource "aws_nat_gateway" "std20_nat_gw" {
  allocation_id = aws_eip.std20_nat_eip.id
  subnet_id     = aws_subnet.create_subnet["public-${local.azs[0]}"].id

  depends_on = [
    aws_internet_gateway.std20_igw
  ]

  tags = {
    Name = "${var.tag_header}nat-gw"
  }
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

resource "aws_route_table" "std20_pub_rt" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${var.tag_header}public-rt"
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
    Name = "${var.tag_header}private-${split("-", each.value.az)[length(split("-", each.value.az)) - 1]}-rt"
  }
}

resource "aws_route_table" "std20_cluster_rt" {
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${var.tag_header}cluster-rt"
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

