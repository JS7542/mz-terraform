# ================================================================================
# EKS 구축 프로세스
# 네트워크 구성 => IAM 권한설정 => EKS 클러스터 생성 => 노드 그룹 정의 => 액세스 환경 정의
# ================================================================================
# 네트워크 설정
# 퍼블릭 서브넷 "kubernetes.io/role/elb" = "1"
# 프라이빗 서브넷 "kubernetes.io/role/internal-elb" = "1"
# ================================================================================
# 1. EKS 및 워커노드를 위한 보안 그룹
# ================================================================================
# 노드와 컨트롤 플레인(k8s 마스터 간) 통신을 위한 포트 : 10250/tcp
# 노드간 통신을 모두 열어줌

resource "aws_security_group" "std20_k8s_sg" {
    name        = "${local.tag_header}k8s-sg"
    description = "Security group for Kubernetes nodes"
    vpc_id      = aws_vpc.std20_vpc.id

    # inbound

    # inbound
    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        self        = true
    }

    ingress {
        from_port   = 10250
        to_port     = 10250
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"      # 모든 프로토콜 허용
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${local.tag_header}k8s-sg"
    }

}

# ================================================================================
# 2. k8s master 및 워커 노드용 IAM 역할 및 정책 생성
# ================================================================================
# 클러스터(k8s)용 역할(role) 생성

resource "aws_iam_role" "std20_k8s_cluster_role" {
    name                = "${local.tag_header}k8s-cluster-role"
    assume_role_policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Effect      = "Allow"
                Principal   = {
                    Service     = "eks.amazonaws.com"
                }
                Action      = "sts:AssumeRole"
            }
        ]
    })
}

# 역할에서 사용할 정책 연결
# 정책 연결 : 콘솔(IAM -> 역할 -> 정책 연결)
resource "aws_iam_role_policy_attachment" "std20_k8s_cluster_role_attachment" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.std20_k8s_cluster_role.name
}

# ================================================================================
# 3. 워커 노드용 IAM 역할 및 정책 생성
# ================================================================================

# 워커 노드용 역할(role) 생성
resource "aws_iam_role" "std20_k8s_worker_role" {
    name                = "${local.tag_header}k8s-worker-role"
    assume_role_policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Effect      = "Allow"
                Principal   = {
                    Service     = "ec2.amazonaws.com"
                }
                Action      = "sts:AssumeRole"
            }
        ]
    })
}

# 역할에서 사용할 정책 연결
resource "aws_iam_role_policy_attachment" "std20_k8s_worker_role_attachment" {
    for_each    = toset(local.node_policies)
    policy_arn  = each.value
    role        = aws_iam_role.std20_k8s_worker_role.name
}

# ================================================================================
# EKS 클러스터 리소스 생성
# ================================================================================

resource "aws_eks_cluster" "std20_eks_cluster" {
    name     = "${local.tag_header}eks-cluster"
    # 클러스터 역할
    role_arn = aws_iam_role.std20_k8s_cluster_role.arn

    # 네트워크 설정
    vpc_config {
        subnet_ids         = [
            for subnet in aws_subnet.std20_pri_subnet : subnet.id
        ]
    }

    # 사용자 연결 설정
    access_config {
        # EKS 클러스터가 사용자나 역할을 어떤 방식으로 인식하게 할지 설정
        # API_AND_CONFIG_MAP / ConfigMap
        authentication_mode = "API_AND_CONFIG_MAP"
        # 생성자에게 자동으로 관리자 권한을 부여하도록 설정
        bootstrap_cluster_creator_admin_permissions = true
    }

    depends_on = [
        aws_iam_role_policy_attachment.std20_k8s_cluster_role_attachment
    ]
}

# ================================================================================
# 4. EKS 워커 노드 그룹 생성
# ================================================================================
# 시작 템플릿 생성
resource "aws_launch_template" "std20_eks_worker_launch_template" {
    name_prefix             = "${local.tag_header}eks-worker-"
    image_id                = data.aws_ami.eks_al2023_latest.id
    instance_type           = "t3.small"
    key_name                = "std20-keypair"
    vpc_security_group_ids  = [
        aws_security_group.std20_k8s_sg.id,
        aws_security_group.std20_internal_alb_sg.id,
        aws_eks_cluster.std20_eks_cluster.vpc_config[0].cluster_security_group_id,
        aws_security_group.std20_ssh_sg.id
    ]
    update_default_version  = true
    # EOF 가 아니라 EOT를 사용합니다.
    user_data = base64encode(<<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.std20_eks_cluster.name}
        apiServerEndpoint: ${aws_eks_cluster.std20_eks_cluster.endpoint}
        certificateAuthority: ${aws_eks_cluster.std20_eks_cluster.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.std20_eks_cluster.kubernetes_network_config[0].service_ipv4_cidr}
  EOT
  )
    tag_specifications {
        resource_type       = "instance"
        tags  = {
            Name = "${local.tag_header}eks-worker"
        }
    }

    tag_specifications {
        resource_type       = "volume"
        tags  = {
            Name = "${local.tag_header}eks-volume"
        }
    }

    tags = {
        Name = "${local.tag_header}eks-worker"
    }
}


# 노드 그룹 생성
resource "aws_eks_node_group" "std20_eks_worker_node_group" {
    node_group_name     = "${local.tag_header}eks-worker"
    cluster_name        = aws_eks_cluster.std20_eks_cluster.name
    node_role_arn       = aws_iam_role.std20_k8s_worker_role.arn

    subnet_ids = [
        for subnet in aws_subnet.std20_pri_subnet : subnet.id
    ]

    scaling_config {
        desired_size    = 2
        max_size        = 3
        min_size        = 1
    }

    launch_template {
        id      = aws_launch_template.std20_eks_worker_launch_template.id
        version = aws_launch_template.std20_eks_worker_launch_template.latest_version   # 삭제 / version =$Default
    }

    depends_on = [
        aws_iam_role_policy_attachment.std20_k8s_worker_role_attachment
    ]
}


# ================================================================================
# 5. [추가] 사용자 연결
# ================================================================================

resource "null_resource" "update_kubeconfig" {
    depends_on = [
        aws_eks_node_group.std20_eks_worker_node_group
    ]
    provisioner "local-exec" {
        command = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.std20_eks_cluster.name}"
    }

}

# ================================================================================
# 사용자 등록
# ================================================================================

resource "aws_eks_access_entry" "bipa17_student20" {
    cluster_name = aws_eks_cluster.std20_eks_cluster.name
    # 등록할 사용자의 계정 ARN
    principal_arn = "arn:aws:iam::925047940866:user/bipa17-student20"

    kubernetes_groups = ["master"]
    type = "STANDARD"

}

resource "aws_eks_access_policy_association" "bipa17_student20_admin" {
    cluster_name = aws_eks_cluster.std20_eks_cluster.name
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    principal_arn = aws_eks_access_entry.bipa17_student20.principal_arn

    access_scope {
        type = "cluster"        # 클러스터 전체
    }
    depends_on = [
        aws_eks_access_entry.bipa17_student20
    ]
}