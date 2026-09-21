# ======================================================================
# 1. IAM Roles & Instance Profile
# ======================================================================

# (1) EC2 Instance Role (ASG Nodes)
resource "aws_iam_role" "asg_node_role" {
  name = "${local.tag_header}AmazonASGNodeEC2-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.asg_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.asg_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.asg_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "asg_node_profile" {
  name = "${local.tag_header}ASGNodeEC2Instance-profile"
  role = aws_iam_role.asg_node_role.name
}

# (2) CodeDeploy Service Role
resource "aws_iam_role" "codedeploy_role" {
  name = "${local.tag_header}AmazonCodeDeployService-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ======================================================================
# 2. Launch Template & UserData
# ======================================================================

# Amazon Linux 2023 최신 AMI 조회 (루트 AWS Provider의 뭄바이 리전)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "asg_lt" {
  name_prefix   = "${local.tag_header}asg-launch-template-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  # 변경: 예제의 고정 SG ID 대신 원본 security 모듈의 실제 ID 연결
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile {
    name = aws_iam_instance_profile.asg_node_profile.name
  }

  # Docker 및 CodeDeploy Agent 자동 설치 스크립트 (base64 자동 인코딩)
  # 제공한 설치 주소는 이미 뭄바이(ap-south-1)이므로 그대로 유지
  user_data = base64encode(<<-EOF_USER_DATA
              #!/bin/bash
              dnf update -y
              dnf install -y ruby wget docker

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user

              cd /tmp
              wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
              chmod +x ./install
              ./install auto

              systemctl start codedeploy-agent
              systemctl enable codedeploy-agent
              EOF_USER_DATA
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.tag_header}asg-node-instance"
    }
  }
}

# ======================================================================
# 3. Auto Scaling Group
# ======================================================================

# 제공한 코드의 태그 조회는 참고용으로 보존합니다.
# 현재 구성에서 만든 cluster 서브넷을 직접 전달하여 다른 VPC와 섞이지 않게 합니다.
# data "aws_subnets" "target_subnets" {
#   filter {
#     name   = "tag:Type"
#     values = ["cluster"]
#   }
# }

resource "aws_autoscaling_group" "asg" {
  name                = "${local.tag_header}codedeploy-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.asg_lt.id
    version = "$Latest"
  }

  # 추가: 시작 시 인스턴스 Role의 정책 연결이 완료되도록 순서 보장
  depends_on = [
    aws_iam_role_policy_attachment.ecr_read,
    aws_iam_role_policy_attachment.s3_read,
    aws_iam_role_policy_attachment.ssm_core
  ]
}

# ======================================================================
# 4. CodeDeploy Application & Deployment Group
# ======================================================================

resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "${local.tag_header}asg-codedeploy-app"
}

resource "aws_codedeploy_deployment_group" "dg" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${local.tag_header}asg-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  autoscaling_groups    = [aws_autoscaling_group.asg.name]

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  # 추가: 서비스 Role의 권한 연결 후 생성
  depends_on = [aws_iam_role_policy_attachment.codedeploy_policy]
}

# ======================================================================
# 5. CodePipeline 서비스 IAM Role
# ======================================================================

resource "aws_iam_role" "codepipeline_role" {
  name = "${local.tag_header}AmazonCodePipelineService-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${local.tag_header}CodePipelineServicePolicy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        # 기존 S3 권한 유지 + 버킷 위치/ACL 조회 권한 보완
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObjectAcl", "s3:PutObject", "s3:GetBucketLocation", "s3:GetBucketAcl"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      # 추가: 원본 예제에서 빠진 GitHub Connection 사용 권한
      {
        Effect   = "Allow"
        Action   = ["codeconnections:UseConnection", "codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

# ======================================================================
# 6. Pipeline Artifacts 저장용 S3 Bucket
# ======================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "pipeline_bucket" {
  bucket        = "${local.tag_header}pipeline-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# ======================================================================
# 연결 작업: AWS - GitHub 간 CodeStar Connection 생성
# ======================================================================
resource "aws_codestarconnections_connection" "github" {
  name          = "${local.tag_header}github-connection"
  provider_type = "GitHub"
}

# =======================================================================
# 7. AWS CodePipeline 생성
# =======================================================================

resource "aws_codepipeline" "codepipeline" {
  name     = "${local.tag_header}asg-cicd-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_bucket.bucket
    type     = "S3"
  }

  # Stage 1: Source (GitHub / CodeStar Connection 기준)
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
      }
    }
  }

  # Stage 2: Deploy (CodeDeploy ASG 배포)
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.dg.deployment_group_name
      }
    }
  }

  # 추가: 파이프라인 실행 권한 연결 후 생성
  depends_on = [aws_iam_role_policy.codepipeline_policy]
}
