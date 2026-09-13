# =============================================================================
# Variables
# =============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-east-1"
}

variable "default_name" {
  description = "Resource name prefix"
  type        = string
  default     = "std20"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Public / Private / Cluster subnet CIDRs"
  type        = list(map(string))

  default = [
    {
      "ap-east-1a" = "10.0.1.0/24"
      "ap-east-1b" = "10.0.2.0/24"
      "ap-east-1c" = "10.0.3.0/24"
    },
    {
      "ap-east-1a" = "10.0.11.0/24"
      "ap-east-1b" = "10.0.12.0/24"
      "ap-east-1c" = "10.0.13.0/24"
    },
    {
      "ap-east-1a" = "10.0.21.0/24"
      "ap-east-1b" = "10.0.22.0/24"
      "ap-east-1c" = "10.0.23.0/24"
    }
  ]
}

variable "ssh_public_key_path" {
  description = "WSL SSH public key path"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "testdb"
}

variable "db_username" {
  description = "MySQL master username"
  type        = string
  default     = "std20"
}
