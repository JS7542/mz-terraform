# ===================================================================
# AWS Secrets Manager 를 통한 보안 암호 생성
# - 기본 생성(Plain text) / JSON 형식 / 랜덤 비밀번호 생성
# ===================================================================
# 보안 암호 생성
resource "aws_secretsmanager_secret" "std20_mysql_password" {
    name            = "project/db/password"
}

# 보안 암호에 실제 사용할 암호 정의(Plain text)
# resource "aws_secretsmanager_secret_version" "std20_mysql_password_value" {
#     secret_id       = aws_secretsmanager_secret.std20_mysql_password.id
#     secret_string   = "melt7542"
# }


# JSON 형식으로 보안 암호 정의
resource "aws_secretsmanager_secret_version" "std20_mysql_password_value" {
    secret_id       = aws_secretsmanager_secret.std20_mysql_password.id
    secret_string   = jsonencode({
        username    = "std20"
        password    = "melt7542"
        database    = "testdb"
    })
}


# 랜덤 비밀번호 생성
resource "random_password" "std20_random_password" {
    length              = 16
    special             = true
    override_special    = "!#$%&*()-_=+[]{}<>:?"
}

# ====================================================================
# 보안 암호 반환
# ====================================================================

# output "secret_db_password" {
#     value = random_password.std20_random_password.result
#     sensitive = true
# }

output "secret_db_password" {
    value = jsondecode(aws_secretsmanager_secret_version.std20_mysql_password_value.secret_string)["password"]
    sensitive = true
}