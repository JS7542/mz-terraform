resource "aws_vpc" "this" {
    cidr_block = local.vpc_cidr       # VPC의 CIDR 블록 설정
    # instance_tenancy = "default"    # 인스턴스 테넌시 설정 (default 또는 dedicated)
    enable_dns_support = true       # DNS 지원 활성화 여부
    enable_dns_hostnames = true     # DNS 호스트 이름 활성화 여부
    tags = {                        # VPC에 적용할 태그 설정
        Name = "${local.tag_header}vpc",
    }
}

# main 으로 넘길때는 아웃풋으로 이 모듈 내부의 아웃풋은 실제로 출력되지 않음.
# output "vpc_id" {
#     value = aws_vpc.this.id
# }

# output "vpc_cidr" {
#     value = local.vpc_cidr
# }

# ======================================================================
# 서브넷 생성
# ======================================================================
resource "aws_subnet" "create_subnet" {
    for_each = local.subnet_map
    vpc_id     = aws_vpc.this.id


    cidr_block = each.value.cidr
    availability_zone = each.value.az

    map_public_ip_on_launch = each.value.type == "public" ? true : false

    enable_resource_name_dns_a_record_on_launch = each.value.type == "public" ? true : false




    tags = {
        Name = "${local.tag_header}${each.key}-subnet"
    }
}

# ======================================================================
# 게이트웨이 설정
# ======================================================================

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
    tags = {
        Name = "${local.tag_header}internet-gateway"
    }
}

# ======================================================================
# NAT 게이트웨이 설정 (필요시)
# ======================================================================

resource "aws_eip" "this" {
    domain = "vpc"

    tags = {
        Name = "${local.tag_header}nat-eip"
    }
}

resource "aws_nat_gateway" "this" {
    allocation_id = aws_eip.this.id

    # map 형식으로 저장되기에 특정 키를 사용하여 접근해야 함
    subnet_id = aws_subnet.create_subnet["public-1a"].id

    tags = {
        Name = "${local.tag_header}nat-gateway"
    }
}

# ======================================================================
# 라우트 테이블 설정 (필요시)
# ======================================================================
# 생성
# 퍼블릭 라우트 테이블 설정
resource "aws_route_table" "std20_pub_rt" {
    vpc_id = aws_vpc.this.id
    
    tags = {
        Name = "${local.tag_header}public-rt"
    }
}


# 프라이빗 라우트 테이블 설정
resource "aws_route_table" "std20_pri_rt" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "private"
    }

    vpc_id = aws_vpc.this.id

    tags = {
        Name = "${local.tag_header}${each.key}-rt"
    }
}


# ======================================================================
# 라우트 테이블 서브넷 연결
# ======================================================================

# 퍼블릭 연결
resource "aws_route_table_association" "std20_pub_rt_assoc" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "public"
    }

    subnet_id      = aws_subnet.create_subnet[each.key].id
    route_table_id = aws_route_table.std20_pub_rt.id
}

# 프라이빗 연결
resource "aws_route_table_association" "std20_pri_rt_assoc" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "private"
    }

    subnet_id      = aws_subnet.create_subnet[each.key].id
    route_table_id = aws_route_table.std20_pri_rt[each.key].id
}

# ======================================================================
# 라우팅 설정
# ======================================================================

# 퍼블릭 --> IGW
resource "aws_route" "std20_pub_rt_to_igw" {
    route_table_id         = aws_route_table.std20_pub_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.this.id
}

# 프라이빗 --> NAT 게이트웨이
resource "aws_route" "std20_pri_rt_to_nat" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "private"
    }
    route_table_id         = aws_route_table.std20_pri_rt[each.key].id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.this.id
}