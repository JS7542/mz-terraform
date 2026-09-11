# =========================================================================
# 엔드포인트 2개 - S3 엔드포인트 / ECR 엔드포인트(효율을 목적으로 2개 생성 예정)
# =========================================================================

# =========================================================================
# S3 엔드포인트 설정
# =========================================================================
# 1. 서비스 데이터 소스 정의(서비스 정의)
# std20-data.tf 참조


# 2. 엔드포인트 생성 및 연결

resource "aws_vpc_endpoint" "std20_s3_endpoint" {
    vpc_id            = aws_vpc.std20_vpc.id
    service_name      = data.aws_vpc_endpoint_service.s3.service_name
    vpc_endpoint_type = "Gateway"

    route_table_ids    = [
        for rt in aws_route_table.std20_pri_rt : rt.id
    ]
    tags = {
        Name = "${local.tag_header}s3-endpoint"
    }
}

# =========================================================================
# ECR 서비스 사용을 위한 인터페이스 엔드포인트
# -ECR API 인터페이스 엔드포인트
#   IAM 인증, 메타데이터 조회, 레포지토리 생성 및 삭제 등 ECR API 관련 작업 수행
#   com.amazonaws.<region>.ecr.api
# -ECR DKR 인터페이스 엔드포인트
#   컨테이너 이미지 풀링 및 푸시 등 ECR DKR 관련 작업 수행
#   com.amazonaws.<region>.ecr.dkr
# =========================================================================

resource "aws_vpc_endpoint" "std20_ecr_api_endpoint" {
    vpc_id            = aws_vpc.std20_vpc.id
    service_name      = "com.amazonaws.${local.region}.ecr.api"
    vpc_endpoint_type = "Interface"

    subnet_ids = [
        for subnet in aws_subnet.std20_pri_subnet : subnet.id
    ]

    # ECR 은 통신포트로 443을 사용함.
    security_group_ids = [
        aws_security_group.std20_external_alb_sg.id
    ]

    # [필수] ECR 의 기본 URL 주소 호환을 위한 필수 옵션
    private_dns_enabled = true

    tags = {
        Name = "${local.tag_header}ecr-api-endpoint"
    }
}


resource "aws_vpc_endpoint" "std20_ecr_dkr_endpoint" {
    vpc_id            = aws_vpc.std20_vpc.id
    service_name      = "com.amazonaws.${local.region}.ecr.dkr"
    vpc_endpoint_type = "Interface"

    subnet_ids = [
        for subnet in aws_subnet.std20_pri_subnet : subnet.id
    ]

    # ECR 은 통신포트로 443을 사용함.
    security_group_ids = [
        aws_security_group.std20_external_alb_sg.id
    ]

    # [필수] ECR 의 기본 URL 주소 호환을 위한 필수 옵션
    private_dns_enabled = true

    tags = {
        Name = "${local.tag_header}ecr-dkr-endpoint"
    }
}