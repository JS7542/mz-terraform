# =============================================================================
# Data Sources
# =============================================================================

data "aws_availability_zones" "available_az" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Ubuntu Server 24.04 LTS
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

# backend에서 사용 중인 Terraform state bucket
data "aws_s3_bucket" "terraform_state" {
  bucket = "std20-terraform-state-bucket"
}
