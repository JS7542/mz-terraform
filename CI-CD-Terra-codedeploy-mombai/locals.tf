locals {
  tag_header = "${var.default_name}-"
  # web_user_data = templatefile("${path.module}/templates/ec2-user-data.sh", {
  #   efs_dns_name = module.storage.efs_dns_name
  # })
}
