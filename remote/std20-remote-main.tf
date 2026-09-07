resource "aws_s3_bucket" "terraform_state" {
    bucket = "std20-terraform-state-bucket"
    
    lifecycle {
        prevent_destroy = true  # 삭제 방지
    }

    tags = {
        Name        = "std20-terraform-state-bucket"
        Environment = "Dev"
    }

}


resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"  # 버전 관리 활성화
    }
}

# ==================================================================
# 2. 상태 잠금용 DynamoDB 테이블 생성
# ==================================================================
resource "aws_dynamodb_table" "terraform_lock" {
    name         = "std20-terraform-state-lock"
    billing_mode = "PROVISIONED"    # DynamoDB 관리 방식(비용과 연관된 설정)
    read_capacity  = 20             # 읽기 처리량 단위  (초당 4KB 읽기 요청 수) - RCU => 1RCU
    write_capacity = 20             # 쓰기 처리량 단위  (초당 4KB 쓰기 요청 수) - WCU => 1WCU
    hash_key = "LockID"             # Primary Key 속성 정의

    
    attribute {
        name = "LockID"             # Primary Key 속성 이름
        type = "S"                  # S(String) , N(Number), B(Binary) 중 하나 선택
    }

    tags = {
        Name        = "std20-terraform-state-lock"
        Environment = "Dev"
    }
}