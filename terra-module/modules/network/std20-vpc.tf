resource "aws_vpc" "this" {
    cidr_block = local.vpc_cidr       # VPC의 CIDR 블록 설정
    # instance_tenancy = "default"    # 인스턴스 테넌시 설정 (default 또는 dedicated)
    enable_dns_support = true       # DNS 지원 활성화 여부
    enable_dns_hostnames = true     # DNS 호스트 이름 활성화 여부
    tags = {                        # VPC에 적용할 태그 설정
        Name = "${local.tag_header}vpc",
    }
}

output "vpc_id" {
    value = aws_vpc.this.id
}