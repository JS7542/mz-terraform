# 모듈 입력은 var.*, 반환값은 module.<모듈명>.<output명>으로 연결합니다.

module "network" {
  source = "./modules/network"

  tag_header = local.tag_header
  vpc_cidr = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}

module "security" {
  source = "./modules/security"

  tag_header = local.tag_header
  vpc_id = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
}

module "compute" {
  source = "./modules/compute"

  tag_header = local.tag_header
  internal_ssh_sg_id = module.security.internal_ssh_sg_id
  web_sg_id = module.security.web_sg_id
  subnet_id = module.network.private_subnet_ids[0]
  ami_id = data.aws_ami.ubuntu_2404.id
  user_data = local.web_user_data
  ssh_public_key_path = var.ssh_public_key_path
}

module "storage" {
  source = "./modules/storage"

  tag_header = local.tag_header
  efs_sg_id = module.security.efs_sg_id
  private_subnet_ids_by_key = module.network.private_subnet_ids_by_key
  account_id = data.aws_caller_identity.current.account_id
}

module "asg" {
  source = "./modules/asg"

  tag_header = local.tag_header
  vpc_id = module.network.vpc_id
  internal_ssh_sg_id = module.security.internal_ssh_sg_id
  external_alb_sg_id = module.security.external_alb_sg_id
  web_sg_id = module.security.web_sg_id
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  ami_id = data.aws_ami.ubuntu_2404.id
  user_data = local.web_user_data
  key_name = module.compute.key_name
}

module "eks" {
  source = "./modules/eks"

  tag_header = local.tag_header
  eks_cluster_sg_id = module.security.eks_cluster_sg_id
  eks_node_sg_id = module.security.eks_node_sg_id
  cluster_subnet_ids = module.network.cluster_subnet_ids
  key_name = module.compute.key_name
  eks_version = var.eks_version
}

module "database" {
  source = "./modules/database"

  tag_header = local.tag_header
  mysql_sg_id = module.security.mysql_sg_id
  private_subnet_ids = module.network.private_subnet_ids
  db_name = var.db_name
  db_username = var.db_username
}

module "endpoints" {
  source = "./modules/endpoints"

  tag_header = local.tag_header
  vpc_id = module.network.vpc_id
  endpoint_sg_id = module.security.endpoint_sg_id
  private_subnet_ids = module.network.private_subnet_ids
  s3_route_table_ids = module.network.s3_route_table_ids
  region = var.region
}

