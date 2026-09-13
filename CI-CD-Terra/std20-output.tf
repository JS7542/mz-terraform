# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  value = aws_vpc.std20_vpc.id
}

output "terraform_state_bucket" {
  value = data.aws_s3_bucket.terraform_state.bucket
}

output "static_web_bucket" {
  value = aws_s3_bucket.std20_static_web_bucket.bucket
}

output "static_web_website_endpoint" {
  value = aws_s3_bucket_website_configuration.std20_static_web_bucket.website_endpoint
}

output "log_bucket" {
  value = aws_s3_bucket.std20_log_bucket.bucket
}

output "efs_id" {
  value = aws_efs_file_system.std20_efs.id
}

output "web_instance_private_ip" {
  value = aws_instance.std20_web_instance.private_ip
}

output "external_alb_dns_name" {
  value = aws_lb.std20_external_alb.dns_name
}

output "eks_cluster_name" {
  value = aws_eks_cluster.std20_eks_cluster.name
}

output "eks_update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.std20_eks_cluster.name}"
}

output "mysql_endpoint" {
  value     = aws_db_instance.std20_mysql_instance.endpoint
  sensitive = true
}

output "mysql_proxy_endpoint" {
  value     = aws_db_proxy.std20_mysql_proxy.endpoint
  sensitive = true
}
