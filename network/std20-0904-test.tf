# resource "aws_instance" "this"  {
#     count           = 2
#     subnet_id       = "subnet-0962aabaa19dc7b54"
#     ami             = "ami-0ed4602584620d2fa"     # ap-east-1 / Ubuntu 24.04 LTS
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "std20-${count.index + 1}-instance"
#     }

# }

# resource "aws_instance" "this"  {
#     for_each  = toset(["logs", "media", "backups"])
#     subnet_id       = "subnet-0962aabaa19dc7b54"
#     ami             = "ami-0ed4602584620d2fa"     # ap-east-1 / Ubuntu 24.04 LTS
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "std20-${each.key}-instance"
#     }

# }

# resource "aws_instance" "this"  {
#     for_each  = {
#         "a" = "logs"
#         "b" = "media"
#         "c" = "backups"
#     }
#     subnet_id       = "subnet-0962aabaa19dc7b54"
#     ami             = "ami-0ed4602584620d2fa"     # ap-east-1 / Ubuntu 24.04 LTS
#     instance_type   = "t3.nano"
#     tags = {
#         Name = "std20-${each.key}-instance"         # each.value
#     }

# }

# output "prt_aws_instance" {
#     value = aws_instance.this["b"].tags
# }

