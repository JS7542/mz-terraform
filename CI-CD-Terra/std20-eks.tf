# =============================================================================
# 5. EKS
# - Node Group 1개
# - min 1 / desired 1 / max 2
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "std20_eks_cluster_role" {
  name = "${local.tag_header}eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.tag_header}eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "std20_eks_cluster_policy" {
  role       = aws_iam_role.std20_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------------------------------------------
# EKS Worker IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "std20_eks_worker_role" {
  name = "${local.tag_header}eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.tag_header}eks-worker-role"
  }
}

resource "aws_iam_role_policy_attachment" "std20_eks_worker_policy" {
  for_each = toset(local.node_policies)

  role       = aws_iam_role.std20_eks_worker_role.name
  policy_arn = each.value
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "std20_eks_cluster" {
  name     = "${local.tag_header}eks-cluster"
  role_arn = aws_iam_role.std20_eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids = [
      for az in local.azs :
      aws_subnet.create_subnet["cluster-${az}"].id
    ]

    security_group_ids = [
      aws_security_group.std20_eks_cluster_sg.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true

    # 학습 환경 기준
    public_access_cidrs = ["0.0.0.0/0"]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.std20_eks_cluster_policy
  ]

  tags = {
    Name = "${local.tag_header}eks-cluster"
  }
}

# -----------------------------------------------------------------------------
# Managed Node Group용 Launch Template
# custom SG / SSH key만 정의하고 AMI는 EKS Managed AMI 사용
# -----------------------------------------------------------------------------

resource "aws_launch_template" "std20_eks_node_lt" {
  name_prefix = "${local.tag_header}eks-node-lt-"
  key_name    = aws_key_pair.std20_keypair.key_name

  vpc_security_group_ids = [
    aws_security_group.std20_eks_node_sg.id
  ]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.tag_header}eks-worker"
    }
  }

  tags = {
    Name = "${local.tag_header}eks-node-lt"
  }
}

resource "aws_eks_node_group" "std20_eks_node_group" {
  cluster_name    = aws_eks_cluster.std20_eks_cluster.name
  node_group_name = "${local.tag_header}eks-worker"
  node_role_arn   = aws_iam_role.std20_eks_worker_role.arn
  version         = var.eks_version
  ami_type        = "AL2023_x86_64_STANDARD"

  subnet_ids = [
    for az in local.azs :
    aws_subnet.create_subnet["cluster-${az}"].id
  ]

  instance_types = ["t3.small"]

  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.std20_eks_node_lt.id
    version = aws_launch_template.std20_eks_node_lt.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.std20_eks_worker_policy
  ]

  tags = {
    Name = "${local.tag_header}eks-worker"
  }
}
