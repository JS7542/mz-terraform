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
  backend "s3" {
    bucket       = "std20-terraform-state-bucket"
    key          = "CI-CD-Terra/terraform.tfstate"
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
