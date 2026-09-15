variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "internal_ssh_sg_id" {
  description = "internal ssh sg id supplied by root module"
  type = string
}

variable "web_sg_id" {
  description = "web sg id supplied by root module"
  type = string
}

variable "subnet_id" {
  description = "subnet id supplied by root module"
  type = string
}

variable "ami_id" {
  description = "ami id supplied by root module"
  type = string
}

variable "user_data" {
  description = "user data supplied by root module"
  type = string
}

variable "ssh_public_key_path" {
  description = "ssh public key path supplied by root module"
  type = string
}

