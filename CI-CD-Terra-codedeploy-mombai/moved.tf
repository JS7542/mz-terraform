# 기존 홍콩 state용 이동 선언입니다. 신규 뭄바이 state에서는 비활성화합니다.
# # 기존 root 리소스 주소를 모듈 주소로 이전합니다. 기존 state를 그대로 사용하세요.
#
# moved {
#   from = aws_vpc.std20_vpc
#   to = module.network.aws_vpc.std20_vpc
# }
#
# moved {
#   from = aws_subnet.create_subnet
#   to = module.network.aws_subnet.create_subnet
# }
#
# moved {
#   from = aws_internet_gateway.std20_igw
#   to = module.network.aws_internet_gateway.std20_igw
# }
#
# moved {
#   from = aws_eip.std20_nat_eip
#   to = module.network.aws_eip.std20_nat_eip
# }
#
# moved {
#   from = aws_nat_gateway.std20_nat_gw
#   to = module.network.aws_nat_gateway.std20_nat_gw
# }
#
# moved {
#   from = aws_route_table.std20_pub_rt
#   to = module.network.aws_route_table.std20_pub_rt
# }
#
# moved {
#   from = aws_route_table.std20_pri_rt
#   to = module.network.aws_route_table.std20_pri_rt
# }
#
# moved {
#   from = aws_route_table.std20_cluster_rt
#   to = module.network.aws_route_table.std20_cluster_rt
# }
#
# moved {
#   from = aws_route_table_association.std20_pub_rt_assoc
#   to = module.network.aws_route_table_association.std20_pub_rt_assoc
# }
#
# moved {
#   from = aws_route_table_association.std20_pri_rt_assoc
#   to = module.network.aws_route_table_association.std20_pri_rt_assoc
# }
#
# moved {
#   from = aws_route_table_association.std20_cluster_rt_assoc
#   to = module.network.aws_route_table_association.std20_cluster_rt_assoc
# }
#
# moved {
#   from = aws_route.std20_pub_rt_internet_access
#   to = module.network.aws_route.std20_pub_rt_internet_access
# }
#
# moved {
#   from = aws_route.std20_pri_rt_nat_access
#   to = module.network.aws_route.std20_pri_rt_nat_access
# }
#
# moved {
#   from = aws_route.std20_cluster_rt_nat_access
#   to = module.network.aws_route.std20_cluster_rt_nat_access
# }
#
# moved {
#   from = aws_security_group.std20_bastion_sg
#   to = module.security.aws_security_group.std20_bastion_sg
# }
#
# moved {
#   from = aws_security_group.std20_internal_ssh_sg
#   to = module.security.aws_security_group.std20_internal_ssh_sg
# }
#
# moved {
#   from = aws_security_group.std20_external_alb_sg
#   to = module.security.aws_security_group.std20_external_alb_sg
# }
#
# moved {
#   from = aws_security_group.std20_web_sg
#   to = module.security.aws_security_group.std20_web_sg
# }
#
# moved {
#   from = aws_security_group.std20_internal_alb_sg
#   to = module.security.aws_security_group.std20_internal_alb_sg
# }
#
# moved {
#   from = aws_security_group.std20_app_sg
#   to = module.security.aws_security_group.std20_app_sg
# }
#
# moved {
#   from = aws_security_group.std20_database_sg
#   to = module.security.aws_security_group.std20_database_sg
# }
#
# moved {
#   from = aws_security_group.std20_eks_cluster_sg
#   to = module.security.aws_security_group.std20_eks_cluster_sg
# }
#
# moved {
#   from = aws_security_group.std20_eks_node_sg
#   to = module.security.aws_security_group.std20_eks_node_sg
# }
#
# moved {
#   from = aws_vpc_security_group_ingress_rule.std20_eks_cluster_from_node
#   to = module.security.aws_vpc_security_group_ingress_rule.std20_eks_cluster_from_node
# }
#
# moved {
#   from = aws_security_group.std20_endpoint_sg
#   to = module.security.aws_security_group.std20_endpoint_sg
# }
#
# moved {
#   from = aws_security_group.std20_efs_sg
#   to = module.security.aws_security_group.std20_efs_sg
# }
#
# moved {
#   from = aws_key_pair.std20_keypair
#   to = module.compute.aws_key_pair.std20_keypair
# }
#
# moved {
#   from = aws_instance.std20_web_instance
#   to = module.compute.aws_instance.std20_web_instance
# }
#
# moved {
#   from = aws_efs_file_system.std20_efs
#   to = module.storage.aws_efs_file_system.std20_efs
# }
#
# moved {
#   from = aws_efs_mount_target.std20_efs_mount_target
#   to = module.storage.aws_efs_mount_target.std20_efs_mount_target
# }
#
# moved {
#   from = aws_s3_bucket.std20_static_web_bucket
#   to = module.storage.aws_s3_bucket.std20_static_web_bucket
# }
#
# moved {
#   from = aws_s3_bucket_public_access_block.std20_static_web_bucket
#   to = module.storage.aws_s3_bucket_public_access_block.std20_static_web_bucket
# }
#
# moved {
#   from = aws_s3_bucket_website_configuration.std20_static_web_bucket
#   to = module.storage.aws_s3_bucket_website_configuration.std20_static_web_bucket
# }
#
# moved {
#   from = aws_s3_bucket_policy.std20_static_web_bucket
#   to = module.storage.aws_s3_bucket_policy.std20_static_web_bucket
# }
#
# moved {
#   from = aws_s3_object.std20_static_web_index
#   to = module.storage.aws_s3_object.std20_static_web_index
# }
#
# moved {
#   from = aws_s3_object.std20_static_web_error
#   to = module.storage.aws_s3_object.std20_static_web_error
# }
#
# moved {
#   from = aws_s3_bucket.std20_log_bucket
#   to = module.storage.aws_s3_bucket.std20_log_bucket
# }
#
# moved {
#   from = aws_s3_bucket_public_access_block.std20_log_bucket
#   to = module.storage.aws_s3_bucket_public_access_block.std20_log_bucket
# }
#
# moved {
#   from = aws_s3_bucket_versioning.std20_log_bucket
#   to = module.storage.aws_s3_bucket_versioning.std20_log_bucket
# }
#
# moved {
#   from = aws_s3_bucket_server_side_encryption_configuration.std20_log_bucket
#   to = module.storage.aws_s3_bucket_server_side_encryption_configuration.std20_log_bucket
# }
#
# moved {
#   from = aws_lb_target_group.std20_web_tg
#   to = module.asg.aws_lb_target_group.std20_web_tg
# }
#
# moved {
#   from = aws_lb.std20_external_alb
#   to = module.asg.aws_lb.std20_external_alb
# }
#
# moved {
#   from = aws_lb_listener.std20_external_alb_http
#   to = module.asg.aws_lb_listener.std20_external_alb_http
# }
#
# moved {
#   from = aws_launch_template.std20_web_lt
#   to = module.asg.aws_launch_template.std20_web_lt
# }
#
# moved {
#   from = aws_autoscaling_group.std20_web_asg
#   to = module.asg.aws_autoscaling_group.std20_web_asg
# }
#
# moved {
#   from = aws_iam_role.std20_eks_cluster_role
#   to = module.eks.aws_iam_role.std20_eks_cluster_role
# }
#
# moved {
#   from = aws_iam_role_policy_attachment.std20_eks_cluster_policy
#   to = module.eks.aws_iam_role_policy_attachment.std20_eks_cluster_policy
# }
#
# moved {
#   from = aws_iam_role.std20_eks_worker_role
#   to = module.eks.aws_iam_role.std20_eks_worker_role
# }
#
# moved {
#   from = aws_iam_role_policy_attachment.std20_eks_worker_policy
#   to = module.eks.aws_iam_role_policy_attachment.std20_eks_worker_policy
# }
#
# moved {
#   from = aws_eks_cluster.std20_eks_cluster
#   to = module.eks.aws_eks_cluster.std20_eks_cluster
# }
#
# moved {
#   from = aws_launch_template.std20_eks_node_lt
#   to = module.eks.aws_launch_template.std20_eks_node_lt
# }
#
# moved {
#   from = aws_eks_node_group.std20_eks_node_group
#   to = module.eks.aws_eks_node_group.std20_eks_node_group
# }
#
# moved {
#   from = random_password.std20_mysql_password
#   to = module.database.random_password.std20_mysql_password
# }
#
# moved {
#   from = aws_db_subnet_group.std20_db_subnet_group
#   to = module.database.aws_db_subnet_group.std20_db_subnet_group
# }
#
# moved {
#   from = aws_db_instance.std20_mysql_instance
#   to = module.database.aws_db_instance.std20_mysql_instance
# }
#
# moved {
#   from = aws_secretsmanager_secret.std20_mysql_secret
#   to = module.database.aws_secretsmanager_secret.std20_mysql_secret
# }
#
# moved {
#   from = aws_secretsmanager_secret_version.std20_mysql_secret
#   to = module.database.aws_secretsmanager_secret_version.std20_mysql_secret
# }
#
# moved {
#   from = aws_iam_role.std20_rds_proxy_role
#   to = module.database.aws_iam_role.std20_rds_proxy_role
# }
#
# moved {
#   from = aws_iam_role_policy.std20_rds_proxy_policy
#   to = module.database.aws_iam_role_policy.std20_rds_proxy_policy
# }
#
# moved {
#   from = aws_db_proxy.std20_mysql_proxy
#   to = module.database.aws_db_proxy.std20_mysql_proxy
# }
#
# moved {
#   from = aws_db_proxy_default_target_group.std20_mysql_proxy_default
#   to = module.database.aws_db_proxy_default_target_group.std20_mysql_proxy_default
# }
#
# moved {
#   from = aws_db_proxy_target.std20_mysql_proxy_target
#   to = module.database.aws_db_proxy_target.std20_mysql_proxy_target
# }
#
# moved {
#   from = aws_vpc_endpoint.std20_s3_endpoint
#   to = module.endpoints.aws_vpc_endpoint.std20_s3_endpoint
# }
#
# moved {
#   from = aws_vpc_endpoint.std20_ecr_api_endpoint
#   to = module.endpoints.aws_vpc_endpoint.std20_ecr_api_endpoint
# }
#
# moved {
#   from = aws_vpc_endpoint.std20_ecr_dkr_endpoint
#   to = module.endpoints.aws_vpc_endpoint.std20_ecr_dkr_endpoint
# }
#
