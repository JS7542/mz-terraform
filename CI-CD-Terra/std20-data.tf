
# 기존에 있는 데이터 값 추출할때 사용
# 현재 사용 가능한 AWS 가용 영역(Availability Zones) 정보를 리스트 형태로 반환
data "aws_availability_zones" "available_az" {
    state = "available"
}

# 퍼블릭 서브넷 데이터 조회
data "aws_subnets" "public_subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.std20_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.tag_header}public-*-subnet"]
  }

  depends_on = [
    aws_subnet.create_subnet
  ]
}

# 프라이빗 서브넷 데이터 조회
data "aws_subnets" "private_subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.std20_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.tag_header}private-*-subnet"]
  }

  depends_on = [
    aws_subnet.create_subnet
  ]
}

# 클러스터 서브넷 데이터 조회
data "aws_subnets" "cluster_subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.std20_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.tag_header}cluster-*-subnet"]
  }

  depends_on = [
    aws_subnet.create_subnet
  ]
}

data "aws_ami" "eks_al2023_latest" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name = "name"
        values = [
            "amazon-eks-node-al2023-x86_64-standard-${local.eks_version}-v*"
        ]
    }

    filter {
        name   = "architecture"
        values = ["x86_64"]
    }
}

data "aws_vpc_endpoint_service" "s3" {
    service           = "s3"
    service_type      = "Gateway"
}