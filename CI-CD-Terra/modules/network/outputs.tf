output "vpc_id" {
  value = aws_vpc.std20_vpc.id
}

output "public_subnet_ids" {
  value = [for az in local.azs : aws_subnet.create_subnet["public-${az}"].id]
}

output "private_subnet_ids" {
  value = [for az in local.azs : aws_subnet.create_subnet["private-${az}"].id]
  # Private EC2의 apt 실행 전에 NAT 라우팅 구성을 완료합니다.
  depends_on = [aws_route.std20_pri_rt_nat_access, aws_route.std20_pub_rt_internet_access, aws_route_table_association.std20_pri_rt_assoc, aws_route_table_association.std20_pub_rt_assoc]
}

output "cluster_subnet_ids" {
  value = [for az in local.azs : aws_subnet.create_subnet["cluster-${az}"].id]
}

output "private_subnet_ids_by_key" {
  value = { for key, subnet in local.subnet_map : key => aws_subnet.create_subnet[key].id if subnet.type == "private" }
}

output "s3_route_table_ids" {
  value = concat([for key in sort(keys(aws_route_table.std20_pri_rt)) : aws_route_table.std20_pri_rt[key].id], [aws_route_table.std20_cluster_rt.id])
}

