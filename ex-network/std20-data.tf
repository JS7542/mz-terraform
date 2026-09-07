# 현재 사용 가능한 AWS 가용 영역(Availability Zones) 정보를 리스트 형태로 반환
data "aws_availability_zones" "available_az" {
    state = "available"
}


# https://docs.aws.amazon.com/cli/latest/reference/