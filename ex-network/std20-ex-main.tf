# terraform init : 테라폼 초기화
# terraform plan : 테라폼을 통해 배포 가능한지 확인 ( --out=filename 옵션을 통해 plan 파일 생성 가능 )
# terraform apply : 테라폼을 통해 실제 리소스를 배포 ( --auto-approve 옵션을 통해 자동 승인 가능 )
# terraform destroy : 테라폼을 통해 배포된 리소스를 삭제 ( --auto-approve 옵션을 통해 자동 승인 가능 )


resource "aws_vpc" "std20_vpc" {
    cidr_block = var.vpc_cidr       # VPC의 CIDR 블록 설정
    instance_tenancy = "default"    # 인스턴스 테넌시 설정 (default 또는 dedicated)
    enable_dns_support = true       # DNS 지원 활성화 여부
    enable_dns_hostnames = true     # DNS 호스트 이름 활성화 여부
    tags = {                        # VPC에 적용할 태그 설정
        Name = "${local.tag_header}vpc",
    }
}


# ================================================================================================
# 퍼블릭 서브넷 설정
# ================================================================================================


resource "aws_subnet" "std20_pub_subnet" {
    for_each = toset(local.azs)
    vpc_id              = aws_vpc.std20_vpc.id
    cidr_block          = var.subnet_cidr[0][each.key]
    availability_zone   = each.key

    # 아래 두개는 퍼블릭 서브넷 설정
    map_public_ip_on_launch = true
    enable_resource_name_dns_a_record_on_launch = true

    tags = {
        Name  = "${local.tag_header}public-${split("-", each.key)[length(split("-", each.key))-1]}-subnet"
    }
}

# ================================================================================================
# 프라이빗 서브넷 설정
# ================================================================================================

resource "aws_subnet" "std20_pri_subnet" {
    for_each = toset(local.azs)
    vpc_id              = aws_vpc.std20_vpc.id
    cidr_block          = var.subnet_cidr[1][each.key]
    availability_zone   = each.key

    tags = {
        Name  = "${local.tag_header}private-${split("-", each.key)[length(split("-", each.key))-1]}-subnet"
    }
}

# ================================================================================================
# 게이트웨이 설정
# ================================================================================================

# 인터넷 게이트웨이 설정
resource "aws_internet_gateway" "std20_igw" {
    vpc_id = aws_vpc.std20_vpc.id

    tags = {
        Name = "${local.tag_header}igw"
    }
}



# NAT 게이트웨이용 EIP 설정
resource "aws_eip" "std20_nat_eip" {
    domain = "vpc"

    tags = {
        Name = "${local.tag_header}nat-eip"
    }
}

# NAT 게이트웨이 설정
resource "aws_nat_gateway" "std20_nat_gw" {
    allocation_id = aws_eip.std20_nat_eip.id
    # NAT 게이트웨이를 생성할 퍼블릭 서브넷 지정
    subnet_id     = aws_subnet.std20_pub_subnet[local.azs[0]].id
    # 인터넷 게이트웨이를 먼저 생성(완료) 되면 이후 NAT 게이트웨이를 생성하도록 의존성 설정
    depends_on = [
        aws_internet_gateway.std20_igw
    ]
    tags = {
        Name = "${local.tag_header}nat-gw"
    }
}


# ================================================================================================
# 라우트 테이블 설정
# ================================================================================================


# 생성
# 퍼블릭 라우트 테이블 설정
resource "aws_route_table" "std20_pub_rt" {
    vpc_id = aws_vpc.std20_vpc.id
    
    tags = {
        Name = "${local.tag_header}public-rt"
    }
}



# 프라이빗 라우트 테이블 설정

resource "aws_route_table" "std20_pri_rt" {
  for_each = toset(local.azs)
  vpc_id = aws_vpc.std20_vpc.id

  tags = {
    Name = "${local.tag_header}private-${split("-", each.key)[length(split("-", each.key))-1]}-rt"
  }
}

# 서브넷 라우트 테이블 연결

resource "aws_route_table_association" "std20_pub_rt_assoc" {
    for_each = toset(local.azs)
    subnet_id      = aws_subnet.std20_pub_subnet[each.key].id
    route_table_id = aws_route_table.std20_pub_rt.id
}


resource "aws_route_table_association" "std20_pri_rt_assoc" {
  for_each = toset(local.azs)

  subnet_id      = aws_subnet.std20_pri_subnet[each.key].id
  route_table_id = aws_route_table.std20_pri_rt[each.key].id
}


# 라우팅 설정

resource "aws_route" "std20_pub_rt_internet_access" {
    route_table_id         = aws_route_table.std20_pub_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.std20_igw.id
}

resource "aws_route" "std20_pri_rt_nat_access" {
  for_each = toset(local.azs)

  route_table_id         = aws_route_table.std20_pri_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.std20_nat_gw.id
}


# =================================================================================
# security group 설정
# =================================================================================

# ssh 접속 허용
resource "aws_security_group" "std20_ssh_sg" {
    name        = "${local.tag_header}ssh-sg"
    description = "Security group for SSH access"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${local.tag_header}ssh-sg"
    }

}

resource "aws_security_group" "std20_mysql_sg" {
    name = "${local.tag_header}mysql-sg"
    description = "Security group for MySQL access"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound
    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}mysql-sg"
    }
}


resource "aws_security_group" "std20_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for web access"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}external-alb-sg"
    }
}

resource "aws_security_group" "allow_direct_web" {
    name        = "${local.tag_header}allow-direct-web-sg"
    description = "Security group for direct web access"
    vpc_id      = aws_vpc.std20_vpc.id
    # inbound
    dynamic "ingress" {
        for_each = [80,443]
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}allow-direct-web-sg"
    }
}



# =================================================================================
# 프라이빗 웹 인스턴스용 보안 그룹 설정
# =================================================================================
resource "aws_security_group" "std20_internal_alb_sg" {
    name        = "${local.tag_header}internal-alb-sg"
    description = "Security group for private web access"
    vpc_id      = aws_vpc.std20_vpc.id


    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}internal-alb-sg"
    }
}

# 보안그룹 규칙 추가 : 외부 ALB에서 내부 ALB로의 접근 허용
resource "aws_security_group_rule" "allow_external_to_internal" {
    type                     = "ingress"
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    # 규칙 추가 할 보안 그룹 ID (내부 ALB)
    security_group_id        = aws_security_group.std20_internal_alb_sg.id
    # 소스 보안 그룹 ID (외부 ALB)
    source_security_group_id = aws_security_group.std20_external_alb_sg.id
}

resource "aws_security_group_rule" "allow_external_to_internal_https" {
    type                     = "ingress"
    from_port                = 443
    to_port                  = 443
    protocol                 = "tcp"
    security_group_id        = aws_security_group.std20_internal_alb_sg.id
    source_security_group_id = aws_security_group.std20_external_alb_sg.id
}

# ================================================================================================
# NACL
# ================================================================================================

# resource "aws_network_acl" "std20_ex_nacl" {
#     vpc_id = aws_vpc.std20_vpc.id


#     ingress {
#         rule_no    = 90            # rule_no 는 중복되지 않게 작성
#         protocol   = "tcp"
#         action = "allow"
#         cidr_block = "0.0.0.0/0"
#         from_port = 22
#         to_port   = 22
#     }

#     ingress {
#         rule_no    = 100            # rule_no 는 중복되지 않게 작성 / ingress, egress 각각 중복되지 않게 작성
#         protocol   = "tcp"
#         action = "allow"
#         cidr_block = "0.0.0.0/0"
#         from_port = 80
#         to_port   = 80
#     }

#     ingress {
#         rule_no    = 110            # rule_no 는 중복되지 않게 작성
#         protocol   = "tcp"
#         action = "allow"
#         cidr_block = "0.0.0.0/0"
#         from_port = 443
#         to_port   = 443
#     }

#     # 응답 임시 포트
#     ingress {
#         rule_no    = 120            # rule_no 는 중복되지 않게 작성
#         protocol   = "tcp"
#         action = "allow"
#         cidr_block = "0.0.0.0/0"
#         from_port = 1024
#         to_port   = 65535
#     }

#     egress {
#         rule_no    = 100
#         protocol   = "-1"
#         action     = "allow"
#         cidr_block = "0.0.0.0/0"
#         from_port = 0
#         to_port   = 0
#     }
#     tags = {
#         Name = "std20-ex-nacl"
#     }
# }

# # 서브넷 연결

# resource "aws_network_acl_association" "std20_ex_nacl_assoc" {
#   for_each = aws_subnet.std20_pub_subnet

#   subnet_id      = each.value.id
#   network_acl_id = aws_network_acl.std20_ex_nacl.id
# }







# =============================================================================
# 테라폼은 선언형 언어, IF 문이 없다.
# if 문을 대체하는 3항 연산자를 통해 간단한 제어만 가능.
# 예 : condition ? true_value : false_value
# [일반 삼항연산자]조건 ? 조건이 참일때의 값 : 조건이 거짓일때의 값
# [다중 삼항연산자]조건1 ? 조건1이 참일때의 값 : (조건2 ? 조건2가 참일때의 값 : 조건2가 거짓일때의 값)      -- 참/거짓 위치는 상관없지만 보통 거짓 부분에 삼항연산자가 하나 더들어감.

# locals{
#     instance_chk = true
# }

# resource "aws_instance" "this"  {
#     count           = local.instance_chk ? 1 : 0
#     ami             = "ami-0ed4602584620d2fa"     # ap-east-1 / Ubuntu 24.04 LTS
#     subnet_id       = aws_subnet.std20_pub_subnet[local.azs[0]].id
#     instance_type   = "t3.nano"

#     tags = {
#         Name = "std20-${count.index + 1}-instance"
#     }

# }


# ---------------------------------------
# 중첩 삼항 연산자
# locals{
#     instance_type = "default"   # "t3.nano" / "t3.micro" / "t3.small"
# }

# resource "aws_instance" "std20-instance" {
#     ami             = "ami-0ed4602584620d2fa"     # ap-east-1 / Ubuntu 24.04 LTS
#     subnet_id       = aws_subnet.std20_pub_subnet[local.azs[0]].id
#     instance_type   = local.instance_type == "default" ? "t3.nano" : (
#                       local.instance_type == "micro" ? "t3.micro" : "t3.small")

#     tags = {
#         Name = "${local.tag_header}pub-${split("-", local.azs[0])[length(split("-", local.azs[0]))-1]}-instance"
#     }

# }

# --------------------------------------------
# 문자열 함수

# output "zfunction_string" {
#     value = "abcd"
# }
# output "zfunction_string_upper" {
#     value = upper("abcd")     # 대문자 변환
# }

# output "zfunction_string_lower" {
#     value = lower("ABCD")     # 소문자 변환
# }

# output "zfunction_string_replace" {
#     value = replace("abcda", "ab", "K")     # 문자열 치환
# }


# 문자열 나누기
# output "zfunction_string_split" {
#     value = split("-", local.azs[2])[length(split("-", local.azs[2]))-1]    # 전체 문자열에서 특정 문자를 기준으로 나누기
# }


# 문자열 합치기
# output "zfunction_string_join" {
#     value = join("*", split("-", "ap-east-1a"))     # 문자열 합치기
# }

# for 표현식 -----------------

# 모두 대문자로 변환
# output "uppers" {
#     value = [for name in ["ap-east-1a", "ap-east-1b", "ap-east-1c"] : upper(name)]
# }

# 짝수 찾기
# output "uppers" {
#     value = [for num in [2,4,5,65,78] : num*num if num % 2 == 0]
# }
