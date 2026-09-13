# =============================================================================
# 6. Database
# - MySQL 8.0.46
# - db.t3.small
# - RDS Proxy target: db_instance_identifier
# =============================================================================

resource "random_password" "std20_mysql_password" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:?"
}

resource "aws_db_subnet_group" "std20_db_subnet_group" {
  name = "${local.tag_header}db-subnet-group"

  subnet_ids = [
    for az in local.azs :
    aws_subnet.create_subnet["private-${az}"].id
  ]

  tags = {
    Name = "${local.tag_header}db-subnet-group"
  }
}

resource "aws_db_instance" "std20_mysql_instance" {
  identifier = "${local.tag_header}mysql-instance"

  engine         = "mysql"
  engine_version = "8.0.46"
  instance_class = "db.t3.small"

  allocated_storage = 20
  storage_type       = "gp3"
  storage_encrypted  = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.std20_mysql_password.result

  db_subnet_group_name = aws_db_subnet_group.std20_db_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.std20_database_sg["mysql"].id
  ]

  publicly_accessible    = false
  multi_az               = false
  backup_retention_period = 7

  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately    = true

  tags = {
    Name = "${local.tag_header}mysql-instance"
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "std20_mysql_secret" {
  name        = "${local.tag_header}mysql-secret"
  description = "MySQL credentials for RDS Proxy"

  tags = {
    Name = "${local.tag_header}mysql-secret"
  }
}

resource "aws_secretsmanager_secret_version" "std20_mysql_secret" {
  secret_id = aws_secretsmanager_secret.std20_mysql_secret.id

  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.std20_mysql_instance.address
    port     = aws_db_instance.std20_mysql_instance.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.std20_mysql_password.result
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "std20_rds_proxy_role" {
  name = "${local.tag_header}rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.tag_header}rds-proxy-role"
  }
}

resource "aws_iam_role_policy" "std20_rds_proxy_policy" {
  name = "${local.tag_header}rds-proxy-policy"
  role = aws_iam_role.std20_rds_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.std20_mysql_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy
# -----------------------------------------------------------------------------

resource "aws_db_proxy" "std20_mysql_proxy" {
  name          = "${local.tag_header}mysql-proxy"
  engine_family = "MYSQL"

  role_arn    = aws_iam_role.std20_rds_proxy_role.arn
  require_tls = true

  idle_client_timeout = 1800

  vpc_subnet_ids = [
    for az in local.azs :
    aws_subnet.create_subnet["private-${az}"].id
  ]

  vpc_security_group_ids = [
    aws_security_group.std20_database_sg["mysql"].id
  ]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.std20_mysql_secret.arn
  }

  depends_on = [
    aws_secretsmanager_secret_version.std20_mysql_secret,
    aws_iam_role_policy.std20_rds_proxy_policy
  ]

  tags = {
    Name = "${local.tag_header}mysql-proxy"
  }
}

resource "aws_db_proxy_default_target_group" "std20_mysql_proxy_default" {
  db_proxy_name = aws_db_proxy.std20_mysql_proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "std20_mysql_proxy_target" {
  db_proxy_name          = aws_db_proxy.std20_mysql_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.std20_mysql_proxy_default.name
  db_instance_identifier = aws_db_instance.std20_mysql_instance.identifier
}
