# ================================================================================
# Lamda Function 에서 사용할 보안그룹 
# ================================================================================
resource "aws_security_group" "std20_lambda_sg" {
    name        = "${local.tag_header}lambda-sg"
    description = "Security group for Lambda function"
    vpc_id      = aws_vpc.std20_vpc.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.tag_header}lambda-sg"
    }
  
}


# ================================================================================
# 보안 암호 생성(형식이 있음)
# 아래는 보안 암호 삭제 AWS CLI 명령어
# aws secretsmanager delete-secret \
#   --secret-id "project/mysql/password" \
#   --force-delete-without-recovery
# ================================================================================

resource "aws_secretsmanager_secret" "std20_mysql_password" {
    name        = "project/mysql/password"
    description = "MySQL password for the project"
}

resource "aws_secretsmanager_secret_version" "std20_mysql_password_value" {
    secret_id       = aws_secretsmanager_secret.std20_mysql_password.id
    # 반드시 아래 JSON 형식(KEY 명 포함)을 유지할것
    secret_string   = jsonencode({
        engine      = "mysql"
        host        = aws_rds_cluster.std20_mysql_cluster.endpoint
        port        = 3306
        username    = "std20"
        password    = "melt7542"
    })
}


# 랜덤 비밀번호 생성
resource "random_password" "std20_random_password" {
    length              = 16
    special             = true
    override_special    = "!#$%&*()-_=+[]{}<>:?"
}



# ================================================================================
# 보안 암호 자동 로테이션 (00일 주기 자동 변경) - CloudFormation
# ================================================================================

#1. CloudFormation 스택을 배포하는 리소스 생성
resource "aws_serverlessapplicationrepository_cloudformation_stack" "std20_mysql_secret_rotation" {
    # cloudFormation 의 스택 이름
    name          = "${local.tag_header}mysql-secret-rotation"
    # 비밀번호 변경에 사용할 원본(기준) 함수(애플리케이션)의 ARN(us-east-1 로 arn 값 고정)
    application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"

    # CloudFormation이 IAM 생성 및 리소스 정책을 정의 할 수 있도록 권한을 부여
    capabilities = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

    # Lambda 함수 동작에 필요한 설정(Parameter)
    parameters = {
        # 람다 함수의 이름
        functionName = "${local.tag_header}mysql-secret-rotation-lambda"
        # 보안 암호(Secrets Manager)의 ENDPOINT 정의
        endpoint = "https://secretsmanager.${local.region}.amazonaws.com"

        # Lambda 함수가 접속해야할 데이터베이스가 포함된 서브넷의 ID 정의
        vpcSubnetIds = join(",", [
            aws_subnet.std20_pri_subnet[local.azs[0]].id,
            aws_subnet.std20_pri_subnet[local.azs[1]].id,
            aws_subnet.std20_pri_subnet[local.azs[2]].id
        ])

        vpcSecurityGroupIds = aws_security_group.std20_lambda_sg.id



    }
}


#2. Secrets Manager에 저장된 암호를 지정된 주기 및 람다 함수를 연결하는 리소스 생성
resource "aws_secretsmanager_secret_rotation" "std20_mysql_secret_rotation" {
    # 바꿀 대상(Secrets Manager에 저장된 암호)
    secret_id           = aws_secretsmanager_secret.std20_mysql_password.id
    # 암호 자동 로테이션에 사용할 Lambda 함수
    rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.std20_mysql_secret_rotation.outputs.RotationLambdaARN

    # 규칙 정의 
    rotation_rules {
        automatically_after_days = 30
    }      
}

# ================================================================================
# RDS 클러스터 생성
# ================================================================================


# 1. 서브넷 그룹 생성
resource "aws_db_subnet_group" "std20_db_subnet_group" {
    name    = "${local.tag_header}db-subnet-group"

    subnet_ids  = data.aws_subnets.private_subnet_ids.ids

    tags = {Name = "${local.tag_header}db-subnet-group"}
}

# 2. RDS 클러스터 생성 : RDS MySQL Multi-AZ DB Cluster
# 주의점 
# 1. Engine의 버전은 반드시 클러스터구성에 사용 할 수 있는 버전으로 지정해 주어야함.
# 2. 볼륨의 Type : gp3/io1을 사용한다.
# 3. 볼륨 타입을 gp3 를 사용할 경우 400GiB 이하의 볼륨 지정시 iops를 주석처리
# 4. 수정(업데이트)의 경우 변경하지 못하게 lifecycle 설정 필요.(변경 설정 무시)

resource "aws_rds_cluster" "std20_mysql_cluster" {
    cluster_identifier          = "${local.tag_header}mysql-cluster"
    
    engine                      = "mysql"
    engine_version              = "8.0.46"

    db_cluster_instance_class   = "db.m5d.large"


    # 볼륨 설정
    storage_type = "gp3"
    allocated_storage           = 100
    # iops                        = 3000
    # throughput                  = 125

    database_name               = "testdb"
    master_username             = "std20"
    master_password             =  random_password.std20_random_password.result

    db_subnet_group_name         = aws_db_subnet_group.std20_db_subnet_group.name
    vpc_security_group_ids       = [aws_security_group.std20_mysql_sg.id]
    skip_final_snapshot          = true             # 실습이니까 true


    # 수정할 때 볼륨으로 인한 에러 발생
    # 이에 최초 생성 이외 apply 때 볼륨변경을 무시하기 위한 설정
    lifecycle {
        ignore_changes = [
            storage_type,
            allocated_storage,
            iops
        ]
    }

    tags = {
        Name = "${local.tag_header}mysql-cluster"
    }
}