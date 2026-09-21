output "mysql_endpoint" {
  value = aws_db_instance.std20_mysql_instance.endpoint
  sensitive = true
}

output "mysql_proxy_endpoint" {
  value = aws_db_proxy.std20_mysql_proxy.endpoint
  sensitive = true
}

