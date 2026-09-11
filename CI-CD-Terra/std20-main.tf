
resource "aws_vpc" "std20_vpc" {
    cidr_block = local.vpc_cidr       # VPC의 CIDR 블록 설정
    instance_tenancy = "default"    # 인스턴스 테넌시 설정 (default 또는 dedicated)
    enable_dns_support = true       # DNS 지원 활성화 여부
    enable_dns_hostnames = true     # DNS 호스트 이름 활성화 여부
    tags = {                        # VPC에 적용할 태그 설정
        Name = "${local.tag_header}vpc",
    }
}


# ================================================================================================
# 서브넷 설정(public subnet: 3 / private subnet: 3 / cluster subnet: 3)
# ================================================================================================
resource "aws_subnet" "create_subnet" {
    for_each = local.subnet_map

    vpc_id            = aws_vpc.std20_vpc.id
    cidr_block        = each.value.cidr
    availability_zone = each.value.az

    map_public_ip_on_launch = each.value.type == "public" ? true : false

    enable_resource_name_dns_a_record_on_launch = each.value.type == "public" ? true : false

    tags = merge(
        {
            Name = "${local.tag_header}${each.value.type}-${split("-", each.value.az)[length(split("-", each.value.az))-1]}-subnet"
            Type = each.value.type
            AZ   = each.value.az
        },

        # Public subnet
        each.value.type == "public" ? {
        "kubernetes.io/role/elb" = "1",
        "kubernetes.io/cluster/${local.tag_header}cluster" = "shared"
        } : {},

        # EKS Cluster subnet
        each.value.type == "cluster" ? {
        "kubernetes.io/role/internal-elb"               = "1"
        "kubernetes.io/cluster/${local.tag_header}cluster" = "shared"
        } : {}
    )
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
    subnet_id = data.aws_subnets.public_subnet_ids.ids[0]
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
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "private"
    }

    vpc_id = aws_vpc.std20_vpc.id

    tags = {
        Name = "${local.tag_header}${each.value.type}-${split("-", each.value.az)[length(split("-", each.value.az))-1]}-rt"
    }
}

# 클러스터 라우트 테이블 설정
resource "aws_route_table" "std20_cluster_rt" {
    vpc_id = aws_vpc.std20_vpc.id

    tags = {
        Name = "${local.tag_header}cluster-rt"
    }
}


# 서브넷 라우트 테이블 연결
# 퍼블릭
resource "aws_route_table_association" "std20_pub_rt_assoc" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "public"
    }

    subnet_id      = aws_subnet.create_subnet[each.key].id
    route_table_id = aws_route_table.std20_pub_rt.id
}

# 프라이빗
resource "aws_route_table_association" "std20_pri_rt_assoc" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "private"
    }

    subnet_id      = aws_subnet.create_subnet[each.key].id
    route_table_id = aws_route_table.std20_pri_rt[each.key].id
}

# 클러스터
resource "aws_route_table_association" "std20_cluster_rt_assoc" {
    for_each = {
        for key, subnet in local.subnet_map :
        key => subnet
        if subnet.type == "cluster"
    }

    subnet_id      = aws_subnet.create_subnet[each.key].id
    route_table_id = aws_route_table.std20_cluster_rt.id
}

# 라우팅 설정
# ============================================================
# Public Route
# Public RT -> IGW
# ============================================================

resource "aws_route" "std20_pub_rt_internet_access" {
  route_table_id         = aws_route_table.std20_pub_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.std20_igw.id
}


# ============================================================
# Private Route
# Private RT 3개 -> NAT Gateway
# ============================================================

resource "aws_route" "std20_pri_rt_nat_access" {
  for_each = aws_route_table.std20_pri_rt

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.std20_nat_gw.id
}


# ============================================================
# Cluster Route
# Cluster RT -> NAT Gateway
# ============================================================

resource "aws_route" "std20_cluster_rt_nat_access" {
  route_table_id         = aws_route_table.std20_cluster_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.std20_nat_gw.id
}

# =================================================================================
# Security Group 설정
# =================================================================================


# =================================================================================
# 1. Bastion Security Group
# 외부에서 Bastion Host SSH 접속
# =================================================================================

resource "aws_security_group" "std20_bastion_sg" {
    name        = "${local.tag_header}bastion-sg"
    description = "Security group for Bastion Host"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - SSH
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
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}bastion-sg"
    }
}



# =================================================================================
# 2. Internal SSH Security Group
# Bastion Host를 통해서만 내부 EC2 SSH 접속
# =================================================================================

resource "aws_security_group" "std20_internal_ssh_sg" {
    name        = "${local.tag_header}internal-ssh-sg"
    description = "Security group for internal SSH access"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - SSH from Bastion
    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_bastion_sg.id]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}internal-ssh-sg"
    }
}



# =================================================================================
# 3. External ALB Security Group
# 인터넷 사용자 -> Public ALB
# =================================================================================

resource "aws_security_group" "std20_external_alb_sg" {
    name        = "${local.tag_header}external-alb-sg"
    description = "Security group for External ALB"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - HTTP
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # inbound - HTTPS
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
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}external-alb-sg"
    }
}



# =================================================================================
# 4. Web Security Group
# External ALB -> Nginx / Web EC2
# =================================================================================

resource "aws_security_group" "std20_web_sg" {
    name        = "${local.tag_header}web-sg"
    description = "Security group for Web Server"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - HTTP from External ALB
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_external_alb_sg.id]
    }

    # inbound - HTTPS from External ALB
    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_external_alb_sg.id]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}web-sg"
    }
}



# =================================================================================
# 5. Internal ALB Security Group
# Web Server -> Internal ALB
# =================================================================================

resource "aws_security_group" "std20_internal_alb_sg" {
    name        = "${local.tag_header}internal-alb-sg"
    description = "Security group for Internal ALB"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - HTTP from Web Server
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_web_sg.id]
    }

    # inbound - HTTPS from Web Server
    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_web_sg.id]
    }

    # inbound - Application Port
    ingress {
        from_port       = 8000
        to_port         = 8000
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_web_sg.id]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}internal-alb-sg"
    }
}



# =================================================================================
# 6. Application Security Group
# Internal ALB -> FastAPI / Application EC2
# =================================================================================

resource "aws_security_group" "std20_app_sg" {
    name        = "${local.tag_header}app-sg"
    description = "Security group for Application Server"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - FastAPI
    ingress {
        from_port       = 8000
        to_port         = 8000
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_internal_alb_sg.id]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}app-sg"
    }
}



# =================================================================================
# 7. Database Security Group 설정
# =================================================================================
resource "aws_security_group" "std20_database_sg" {
    for_each = local.database_sg

    name        = "${local.tag_header}${each.value.name}"
    description = "Security group for ${each.key}"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - Application / EKS
    ingress {
        from_port = each.value.port
        to_port   = each.value.port
        protocol  = "tcp"

        security_groups = [
            aws_security_group.std20_app_sg.id,
            aws_security_group.std20_eks_node_sg.id
        ]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}${each.value.name}"
    }
}

# =================================================================================
# 8. EKS Cluster Security Group
# Worker Node -> EKS Control Plane
# =================================================================================
resource "aws_security_group" "std20_eks_cluster_sg" {
    name        = "${local.tag_header}eks-cluster-sg"
    description = "Security group for EKS Cluster"
    vpc_id      = aws_vpc.std20_vpc.id

    # 관리자 kubectl 접근
    # 실습 환경 기준 전체 허용
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
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}eks-cluster-sg"
    }
}


# =================================================================================
# 9. EKS Worker Node Security Group
# =================================================================================


resource "aws_security_group" "std20_eks_node_sg" {
    name        = "${local.tag_header}eks-node-sg"
    description = "Security group for EKS Worker Nodes"
    vpc_id      = aws_vpc.std20_vpc.id

    # External ALB -> Worker Node HTTP
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_external_alb_sg.id]
    }

    # External ALB -> Worker Node HTTPS
    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_external_alb_sg.id]
    }

    # External ALB -> NodePort
    ingress {
        from_port       = 30000
        to_port         = 32767
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_external_alb_sg.id]
    }

    # EKS Control Plane -> Kubelet
    ingress {
        from_port       = 10250
        to_port         = 10250
        protocol        = "tcp"
        security_groups = [aws_security_group.std20_eks_cluster_sg.id]
    }

    # Worker Node <-> Worker Node
    ingress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        self      = true
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}eks-node-sg"
    }
}

# =================================================================================
# EKS Node -> Cluster
# Kubernetes API Server 접근
# =================================================================================

resource "aws_vpc_security_group_ingress_rule" "std20_eks_cluster_from_node" {
    security_group_id = aws_security_group.std20_eks_cluster_sg.id

    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"

    referenced_security_group_id = aws_security_group.std20_eks_node_sg.id

    description = "Allow HTTPS from EKS Worker Nodes"
}
# =================================================================================
# EKS Cluster -> Node
# Kubelet 통신
# =================================================================================

resource "aws_vpc_security_group_ingress_rule" "std20_eks_node_from_cluster" {
    security_group_id = aws_security_group.std20_eks_node_sg.id

    from_port   = 10250
    to_port     = 10250
    ip_protocol = "tcp"

    referenced_security_group_id = aws_security_group.std20_eks_cluster_sg.id

    description = "Allow Kubelet traffic from EKS Cluster"
}

# =========================================================================
# VPC Endpoint Security Group
# ECR API / ECR DKR Interface Endpoint에서 사용
# =========================================================================

resource "aws_security_group" "std20_endpoint_sg" {
    name        = "${local.tag_header}endpoint-sg"
    description = "Security group for VPC Interface Endpoints"
    vpc_id      = aws_vpc.std20_vpc.id

    # VPC 내부 -> Interface Endpoint HTTPS
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = [local.vpc_cidr]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}endpoint-sg"
    }
}
# =================================================================================
# 2. EFS Security Group
#
# Web EC2 / App EC2 / EKS Worker Node에서
# TCP 2049 포트로 EFS 접근 허용
# =================================================================================

resource "aws_security_group" "std20_efs_sg" {
    name        = "${local.tag_header}efs-sg"
    description = "Security group for EFS"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound - NFS
    ingress {
        from_port = 2049
        to_port   = 2049
        protocol  = "tcp"

        security_groups = [
            aws_security_group.std20_web_sg.id,
            aws_security_group.std20_app_sg.id,
            aws_security_group.std20_eks_node_sg.id
        ]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}efs-sg"
    }
}