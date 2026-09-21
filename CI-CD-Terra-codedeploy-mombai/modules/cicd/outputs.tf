output "asg_name" {
  value = aws_autoscaling_group.asg.name
}
output "connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}
output "pipeline_name" {
  value = aws_codepipeline.codepipeline.name
}
output "codedeploy_app_name" {
  value = aws_codedeploy_app.app.name
}
output "deployment_group_name" {
  value = aws_codedeploy_deployment_group.dg.deployment_group_name
}
