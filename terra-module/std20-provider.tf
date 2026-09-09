# std20-provider.tf
# ======================================================
# 1. 테라폼 실행 환경 설정 블록
# ======================================================

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"                           # 프로바이더 라이브러리 다운로드 경로
            version = "~> 6.0"                                  # 사용할 버전 정의 (6.x 중 최신버전)
        }
    }


    # 협업을 위한 원격 상태 저장소 설정
    backend "s3" {
        bucket = "std20-terraform-state-bucket"                 # S3 버킷 이름
        key    = "terra-module/terraform.tfstate"                # 상태 파일 경로
        region = "ap-east-1"                                    # S3 버킷이 위치한 리전
        dynamodb_table = "std20-terraform-state-lock"           # 상태 잠금용 DynamoDB 테이블 이름
        encrypt = true                                           # 상태 파일 암호화 여부
    }
}

provider "aws" {
    region = "ap-east-1"                                        # AWS 리전 설정
    default_tags {          
        tags = {                                                # 일반적으로 이렇게 입력하지 않고, variables.tf 등을 통해 관리함
            Owner   = "std20"
            Class   = "bipa17"
        }
    }
}

# provider "aws" {
#     alias           = "seoul"
#     region          = "ap-northeast-2"                                        # AWS 리전 설정
#     default_tags {          
#         tags = {                                                # 일반적으로 이렇게 입력하지 않고, variables.tf 등을 통해 관리함
#             Owner   = "std20"
#             Class   = "bipa17"
#         }
#     }
    
# }