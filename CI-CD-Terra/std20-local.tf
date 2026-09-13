# =============================================================================
# Locals
# =============================================================================

locals {
  tag_header = "${var.default_name}-"
  vpc_cidr   = var.vpc_cidr
  region     = var.region

  # subnet_cidr에 정의된 3개 AZ만 사용
  azs = sort(keys(var.subnet_cidr[0]))

  subnet_types = [
    "public",
    "private",
    "cluster"
  ]

  subnet_map = merge([
    for idx, subnet_group in var.subnet_cidr : {
      for az, cidr in subnet_group :
      "${local.subnet_types[idx]}-${az}" => {
        type = local.subnet_types[idx]
        cidr = cidr
        az   = az
      }
    }
  ]...)

  public_subnet_keys = [
    for key, subnet in local.subnet_map : key
    if subnet.type == "public"
  ]

  private_subnet_keys = [
    for key, subnet in local.subnet_map : key
    if subnet.type == "private"
  ]

  cluster_subnet_keys = [
    for key, subnet in local.subnet_map : key
    if subnet.type == "cluster"
  ]

  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  database_sg = {
    mysql = {
      name = "internal-mysql-sg"
      port = 3306
    }

    mariadb = {
      name = "internal-mariadb-sg"
      port = 3306
    }

    postgresql = {
      name = "internal-postgresql-sg"
      port = 5432
    }

    oracle = {
      name = "internal-oracle-sg"
      port = 1521
    }

    mssql = {
      name = "internal-mssql-sg"
      port = 1433
    }

    redis = {
      name = "internal-redis-sg"
      port = 6379
    }
  }
}
