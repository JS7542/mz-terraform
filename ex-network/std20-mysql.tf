# # mysql.tf
# # ################################################################################
# # 서브넷 그룹 생성
# # ================================================================================


# resource "aws_db_subnet_group" "std20_db_subnet_group" {
#     name    = "${local.tag_header}db-subnet-group"

#     subnet_ids  = data.aws_subnets.public_subnet_ids.ids

#     tags = {Name = "${local.tag_header}db-subnet-group"}
# }

# # ################################################################################
# # MySQL Instance 생성
# # ================================================================================
# resource "aws_db_instance" "std20_mysql_instance" {
#     identifier      = "${local.tag_header}mysql-instance"
#     engine          = "mysql"
#     engine_version  = "8.0"
#     instance_class  = "db.t3.micro" # 연습용
#     allocated_storage   = 20 # 최소사양

#     db_name             = jsondecode(aws_secretsmanager_secret_version.std20_mysql_password_value.secret_string)["database"]
#     username            = jsondecode(aws_secretsmanager_secret_version.std20_mysql_password_value.secret_string)["username"]
#     password            = jsondecode(aws_secretsmanager_secret_version.std20_mysql_password_value.secret_string)["password"]

#     db_subnet_group_name    = aws_db_subnet_group.std20_db_subnet_group.name
#     availability_zone       = local.azs[0]
#     # availability_zone       = data.aws_availability_zones.available_az[0].name

#     vpc_security_group_ids = [
#         aws_security_group.std20_mysql_sg.id
#     ]

#     # 백업(최소 7일)
#     backup_retention_period = 7
#     # instance를 삭제할 때 마지막 백업 스냅샷의 생성 여부
#     skip_final_snapshot     = true

#     tags = { Name = "${local.tag_header}mysql-instance" }
# }
