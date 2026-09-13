# =============================================================================
# Endpoint
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Gateway Endpoint
# Public을 제외한 Private / Cluster route table에 연결
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "std20_s3_endpoint" {
  vpc_id            = aws_vpc.std20_vpc.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [
      for key in sort(keys(aws_route_table.std20_pri_rt)) :
      aws_route_table.std20_pri_rt[key].id
    ],
    [
      aws_route_table.std20_cluster_rt.id
    ]
  )

  tags = {
    Name = "${local.tag_header}s3-endpoint"
  }
}

# -----------------------------------------------------------------------------
# ECR API Interface Endpoint
#
# Interface Endpoint는 한 Endpoint당 동일 AZ에 subnet 1개만 선택할 수 있다.
# 따라서 3개 AZ의 Private subnet에 ENI를 생성하고,
# Cluster subnet에서도 VPC 내부 라우팅으로 해당 endpoint에 접근한다.
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "std20_ecr_api_endpoint" {
  vpc_id            = aws_vpc.std20_vpc.id
  service_name      = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    for az in local.azs :
    aws_subnet.create_subnet["private-${az}"].id
  ]

  security_group_ids = [
    aws_security_group.std20_endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${local.tag_header}ecr-api-endpoint"
  }
}

# -----------------------------------------------------------------------------
# ECR DKR Interface Endpoint
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "std20_ecr_dkr_endpoint" {
  vpc_id            = aws_vpc.std20_vpc.id
  service_name      = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    for az in local.azs :
    aws_subnet.create_subnet["private-${az}"].id
  ]

  security_group_ids = [
    aws_security_group.std20_endpoint_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${local.tag_header}ecr-dkr-endpoint"
  }
}
