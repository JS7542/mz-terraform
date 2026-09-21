# =============================================================================
# Terraform / Provider / Backend
# =============================================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Terraform backend용 S3 버킷은 terraform init 이전에 존재해야 한다.
  # 기존 state와 분리하기 위해 key만 변경했습니다.
  # 아래 region은 S3 상태 버킷이 있는 홍콩입니다. 배포 리전은 var.region(뭄바이).
  backend "s3" {
    bucket       = "std20-terraform-state-bucket"
    key          = "CI-CD-Terra-Mumbai/terraform.tfstate"
    region       = "ap-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner = var.default_name
      Class = "bipa17"
    }
  }
}
