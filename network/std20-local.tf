# local.tf
# ================================================================
# 1. 로컬 환경 설정 블록
# 정의된 값의 변경없이 사용하는 변수
# local 에서는 variable 값을 들고 올 수있지만, variable 에서는 local 값을 참조할 수 없다.
# ================================================================
locals {
    tag_header      = "${var.default_name}-"
    azs             = data.aws_availability_zones.available_az.names
}

