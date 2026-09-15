variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "vpc_cidr" {
  description = "vpc cidr supplied by root module"
  type = string
}

variable "subnet_cidr" {
  description = "subnet cidr supplied by root module"
  type = list(map(string))
}

