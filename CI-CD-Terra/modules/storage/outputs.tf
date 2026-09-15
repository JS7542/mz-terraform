output "static_web_website_endpoint" {
  value = aws_s3_bucket_website_configuration.std20_static_web_bucket.website_endpoint
}

output "static_web_bucket" {
  value = aws_s3_bucket.std20_static_web_bucket.bucket
}

output "log_bucket" {
  value = aws_s3_bucket.std20_log_bucket.bucket
}

output "efs_id" {
  value = aws_efs_file_system.std20_efs.id
}

output "efs_dns_name" {
  value = aws_efs_file_system.std20_efs.dns_name
  # EC2가 EFS mount target 생성 후 시작하도록 의존성을 전달합니다.
  depends_on = [aws_efs_mount_target.std20_efs_mount_target]
}

