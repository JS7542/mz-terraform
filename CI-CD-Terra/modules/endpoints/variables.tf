variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "vpc_id" {
  description = "vpc id supplied by root module"
  type = string
}

variable "endpoint_sg_id" {
  description = "endpoint sg id supplied by root module"
  type = string
}

variable "private_subnet_ids" {
  description = "private subnet ids supplied by root module"
  type = list(string)
}

variable "s3_route_table_ids" {
  description = "s3 route table ids supplied by root module"
  type = list(string)
}

variable "region" {
  description = "region supplied by root module"
  type = string
}

