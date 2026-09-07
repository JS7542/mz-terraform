resource "aws_vpc" "std20_ex_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "std20_ex_vpc"
    }
}