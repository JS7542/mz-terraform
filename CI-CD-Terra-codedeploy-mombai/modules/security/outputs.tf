output "internal_ssh_sg_id" {
  value = aws_security_group.std20_internal_ssh_sg.id
}

output "web_sg_id" {
  value = aws_security_group.std20_web_sg.id
}

output "efs_sg_id" {
  value = aws_security_group.std20_efs_sg.id
}

output "external_alb_sg_id" {
  value = aws_security_group.std20_external_alb_sg.id
}

output "eks_cluster_sg_id" {
  value = aws_security_group.std20_eks_cluster_sg.id
}

output "eks_node_sg_id" {
  value = aws_security_group.std20_eks_node_sg.id
}

output "mysql_sg_id" {
  value = aws_security_group.std20_database_sg["mysql"].id
}

output "endpoint_sg_id" {
  value = aws_security_group.std20_endpoint_sg.id
}

