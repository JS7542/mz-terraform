# =============================================================================
# Locals
# =============================================================================

locals {
  vpc_cidr   = var.vpc_cidr

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

}
