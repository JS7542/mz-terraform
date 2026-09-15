variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "efs_sg_id" {
  description = "efs sg id supplied by root module"
  type = string
}

variable "private_subnet_ids_by_key" {
  description = "private subnet ids by key supplied by root module"
  type = map(string)
}

variable "account_id" {
  description = "account id supplied by root module"
  type = string
}

