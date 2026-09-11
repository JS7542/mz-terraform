# local.tf
# ================================================================
# 1. 로컬 환경 설정 블록
# 정의된 값의 변경없이 사용하는 변수
# local 에서는 variable 값을 들고 올 수있지만, variable 에서는 local 값을 참조할 수 없다.
# ================================================================
locals {
    tag_header      = "${var.default_name}-"
    azs             = data.aws_availability_zones.available_az.names
    # ami_id          = data.aws_ami.std20_local_nginx_ami.id
    eks_version = "1.35"
    vpc_cidr        = var.vpc_cidr
    region          = var.region
    node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    # ECR 레포지토리 이미지 읽기
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    # SSM: SSH 없이 터미널 접속 가능
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # Logging: 파드 및 시스템 로그 전송
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    # S3: 설정 파일이나 이미지 읽기 (필요 시 수정)
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ]

    subnet_types     = [
        "public",
        "private",
        "cluster"
    ]

    subnet_map = merge([
        for idx , subnet_group in var.subnet_cidr : {
            for az, cidr in subnet_group : 
            "${local.subnet_types[idx]}-${az}" => {
                type    = local.subnet_types[idx]
                cidr    = cidr
                az      = az

            }
        }
    ]...)

    database_sg = {
        mysql = {
            name = "internal-mysql-sg"
            port = 3306
        }

        mariadb = {
            name = "internal-mariadb-sg"
            port = 3306
        }

        postgresql = {
            name = "internal-postgresql-sg"
            port = 5432
        }

        oracle = {
            name = "internal-oracle-sg"
            port = 1521
        }

        mssql = {
            name = "internal-mssql-sg"
            port = 1433
        }

        redis = {
            name = "internal-redis-sg"
            port = 6379
        }
    }
}
