# =============================================================================
# 3. Store
# =============================================================================

# -----------------------------------------------------------------------------
# EFS 1ea
# -----------------------------------------------------------------------------

resource "aws_efs_file_system" "std20_efs" {
  creation_token = "${local.tag_header}efs"

  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${local.tag_header}efs"
  }
}

# AZ별 Private subnet에 Mount Target 1개씩 생성
resource "aws_efs_mount_target" "std20_efs_mount_target" {
  for_each = {
    for key, subnet in local.subnet_map :
    key => subnet
    if subnet.type == "private"
  }

  file_system_id = aws_efs_file_system.std20_efs.id
  subnet_id      = aws_subnet.create_subnet[each.key].id

  security_groups = [
    aws_security_group.std20_efs_sg.id
  ]
}

# -----------------------------------------------------------------------------
# S3 - Static Web Site bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "std20_static_web_bucket" {
  bucket        = "${local.tag_header}static-web-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${local.tag_header}static-web-bucket"
    Role = "StaticWebSite"
  }
}

resource "aws_s3_bucket_public_access_block" "std20_static_web_bucket" {
  bucket = aws_s3_bucket.std20_static_web_bucket.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "std20_static_web_bucket" {
  bucket = aws_s3_bucket.std20_static_web_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "std20_static_web_bucket" {
  bucket = aws_s3_bucket.std20_static_web_bucket.id

  depends_on = [
    aws_s3_bucket_public_access_block.std20_static_web_bucket
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.std20_static_web_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "std20_static_web_index" {
  bucket       = aws_s3_bucket.std20_static_web_bucket.id
  key          = "index.html"
  content_type = "text/html; charset=utf-8"

  content = <<-HTML
    <!doctype html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>std20</title></head>
      <body><h1>std20 Terraform Learning Infrastructure</h1></body>
    </html>
  HTML
}

resource "aws_s3_object" "std20_static_web_error" {
  bucket       = aws_s3_bucket.std20_static_web_bucket.id
  key          = "error.html"
  content_type = "text/html; charset=utf-8"

  content = <<-HTML
    <!doctype html>
    <html lang="ko">
      <head><meta charset="utf-8"><title>Error</title></head>
      <body><h1>Error</h1></body>
    </html>
  HTML
}

# -----------------------------------------------------------------------------
# S3 - Log bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "std20_log_bucket" {
  bucket        = "${local.tag_header}logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${local.tag_header}log-bucket"
    Role = "LogStorage"
  }
}

resource "aws_s3_bucket_public_access_block" "std20_log_bucket" {
  bucket = aws_s3_bucket.std20_log_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "std20_log_bucket" {
  bucket = aws_s3_bucket.std20_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "std20_log_bucket" {
  bucket = aws_s3_bucket.std20_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
