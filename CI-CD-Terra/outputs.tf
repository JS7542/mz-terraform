# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  value = module.network.vpc_id
}

output "terraform_state_bucket" {
  value = data.aws_s3_bucket.terraform_state.bucket
}

output "static_web_bucket" {
  value = module.storage.static_web_bucket
}

output "static_web_website_endpoint" {
  value = module.storage.static_web_website_endpoint
}

output "log_bucket" {
  value = module.storage.log_bucket
}

output "efs_id" {
  value = module.storage.efs_id
}

output "web_instance_private_ip" {
  value = module.compute.web_instance_private_ip
}

# output "external_alb_dns_name" {
#   value = module.asg.external_alb_dns_name
# }

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.eks_cluster_name}"
}

## output "mysql_endpoint" {
##   value     = module.database.mysql_endpoint
##   sensitive = true
## }

## output "mysql_proxy_endpoint" {
##   value     = module.database.mysql_proxy_endpoint
##   sensitive = true
## }
