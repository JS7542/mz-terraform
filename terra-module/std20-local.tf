# local.tf
# ================================================================
# 1. 로컬 환경 설정 블록
# 정의된 값의 변경없이 사용하는 변수
# local 에서는 variable 값을 들고 올 수있지만, variable 에서는 local 값을 참조할 수 없다.
# ================================================================

# <변수명> = <모듈명.아웃풋 이름>
locals {
    tag_header      = var.owner == "" ? "" : "${var.owner}-"
    # ["ap-east-1a", ...]
    az_names        = data.aws_availability_zones.available_az.names
    # ami_id          = data.aws_ami.std20_local_nginx_ami.id
    region          = var.region
    owner           = var.owner
    vpc_cidr        = var.vpc_cidr
    vpc_cidr_header = "${split(".", local.vpc_cidr)[0]}.${split(".", local.vpc_cidr)[1]}"
    subnet_map      = merge([
        for idx, key in ["public","private"] : {
            for i, az_name in local.az_names :"${key}-${split("-", az_name)[2]}" => {
                type        = key
                az          = az_name
                cidr        = "${local.vpc_cidr_header}.${idx*10+1+i}.0/24"
            }
        }
    ]...)
}