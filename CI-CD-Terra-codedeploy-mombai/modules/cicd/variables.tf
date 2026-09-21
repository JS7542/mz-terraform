variable "tag_header" {
  type = string
}
variable "security_group_ids" {
  type = list(string)
}
variable "subnet_ids" {
  type = list(string)
}
variable "github_repository" {
  type = string
}
variable "github_branch" {
  type = string
}
