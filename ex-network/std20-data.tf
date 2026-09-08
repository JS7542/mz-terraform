# 현재 사용 가능한 AWS 가용 영역(Availability Zones) 정보를 리스트 형태로 반환
data "aws_availability_zones" "available_az" {
    state = "available"
}

data "aws_ami" "std20_local_nginx_ami" {
    most_recent = true
    owners      = ["self"]  # Canonical (Ubuntu) 소유자 ID

    filter {
        name   = "tag:Name"
        values = ["${local.tag_header}web-instance-ami"]
    }

    filter {
        name   = "tag:Owner"
        values = ["std20"]
    }

}