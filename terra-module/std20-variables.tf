# variables.tf

variable "region" {
  description = "The AWS region to deploy resources in"         # 말 그대로 설명 안써도 무방함
  type        = string
  default     = "ap-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "owner"{
  description = "사용자 계정명"
  type        = string
  default     = "student24"
}