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

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = list(map(string))
  default     = [
    {
      "ap-east-1a" = "10.0.1.0/24", 
      "ap-east-1b" = "10.0.2.0/24", 
      "ap-east-1c" = "10.0.3.0/24"
    },
    {
      "ap-east-1a" = "10.0.11.0/24", 
      "ap-east-1b" = "10.0.12.0/24", 
      "ap-east-1c" = "10.0.13.0/24"
    }
  ]
}


variable "tag_header" {
  description = "The tag header to be used for all resources"
  type        = string
  default     = "std20-"
  
}

variable "default_name" {
  description = "The default name to be used for local tag header"
  type        = string
  default     = "std20-"
}