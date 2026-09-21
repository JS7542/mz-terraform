variable "tag_header" {
  description = "tag header supplied by root module"
  type = string
}

variable "eks_cluster_sg_id" {
  description = "eks cluster sg id supplied by root module"
  type = string
}

variable "eks_node_sg_id" {
  description = "eks node sg id supplied by root module"
  type = string
}

variable "cluster_subnet_ids" {
  description = "cluster subnet ids supplied by root module"
  type = list(string)
}

variable "key_name" {
  description = "key name supplied by root module"
  type = string
}

variable "eks_version" {
  description = "eks version supplied by root module"
  type = string
}

