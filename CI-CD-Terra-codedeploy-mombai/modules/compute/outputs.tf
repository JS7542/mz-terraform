output "key_name" {
  value = var.key_name
}

output "web_instance_private_ip" {
  value = aws_instance.std20_web_instance.private_ip
}

