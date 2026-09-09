# 내가 모듈한테 넘길때는 변수 모듈이 메인으로넘길때는 아웃풋
# 사용할 모듈 블럭
module "network" {
    source = "./modules/network"

    # 다른 리전을 사용하고자 할 경우, providers 블록을 사용하여 별도의 프로바이더를 지정할 수 있음
    # providers = {
    #     aws =   aws.seoul
    # }

    # <모듈 변수명> = <모듈 넘겨줄 값> | var.변수명 | local.변수명

    az_names            = local.az_names
    owner               = local.owner
    vpc_cidr            = local.vpc_cidr
    tag_header          = local.tag_header
}

output "vpc_id" {
    value = module.network.vpc_id
}