
# 기존에 있는 데이터 값 추출할때 사용
# 현재 사용 가능한 AWS 가용 영역(Availability Zones) 정보를 리스트 형태로 반환
data "aws_availability_zones" "available_az" {
    state = "available"
}

# data "aws_ami" "std20_local_nginx_ami" {
#     most_recent = true
#     owners      = ["self"]  # Canonical (Ubuntu) 소유자 ID

#     filter {
#         name   = "tag:Name"
#         values = ["${local.tag_header}web-instance-ami"]
#     }

#     filter {
#         name   = "tag:Owner"
#         values = ["std20"]
#     }

# }

data "aws_subnets" "public_subnet_ids" {
    filter {
        name    = "tag:Name"
        values  = [
            "${local.tag_header}public-1a-subnet",
            "${local.tag_header}public-1b-subnet",
            "${local.tag_header}public-1c-subnet",
        ]
    }
}

data "aws_subnets" "private_subnet_ids" {
    filter {
        name    = "tag:Name"
        values  = [
            "${local.tag_header}private-1a-subnet",
            "${local.tag_header}private-1b-subnet",
            "${local.tag_header}private-1c-subnet",
        ]
    }
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