variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "mysql_sg_id" {
  description = "mysql sg id supplied by root module"
  type = string
}

variable "private_subnet_ids" {
  description = "private subnet ids supplied by root module"
  type = list(string)
}

variable "db_name" {
  description = "db name supplied by root module"
  type = string
}

variable "db_username" {
  description = "db username supplied by root module"
  type = string
}

