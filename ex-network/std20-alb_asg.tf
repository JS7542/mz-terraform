# ===================================================================
# 대상 그룹 생성
# ===================================================================
resource "aws_lb_target_group" "std20_web_instance_tg" {
    name                        = "${local.tag_header}web-instance-tg"
    vpc_id                      = aws_vpc.std20_vpc.id

    protocol                    = "HTTP"
    port                        = 80                # 내부 웹서버의 실행 포트번호(서비스의 포트번호와 맞춰주어야 한다.)

    # 인스턴스 연결 대기 시간 정의
    slow_start                  = 30                # 30 초 동안 연결 대기    
    # 인스턴스 종료(삭제)시 연결 유지 시간 정의
    deregistration_delay        = 60                # 60 초 동안 연결 유지
    
    # 헬스 체크 설정
    health_check {
        protocol                = "HTTP"
        path                    = "/"
        port                    = "traffic-port"    # 기본값으로 위 서비스의 포트번호를 따라감.

        interval                = 15                # 헬스 체크 간격(초)
        timeout                 = 5                 # 응답을 기다리는 시간(초)

        # 최종 성공/실패 판단 기준(횟수)
        healthy_threshold       = 3                 # 연속 성공 횟수    (보통 k8s 나 docker swarm 에서는 적게 잡음 - 인스턴스가 아닌 컨테이너 단위로 헬스 체크를 하기 때문에)
        unhealthy_threshold     = 3                 # 연속 실패 횟수
    }

    tags = {
        Name = "${local.tag_header}web-instance-tg"
    }

}
# ========================================================
# 로드 밸런서 생성
# ========================================================
resource "aws_lb" "std20_external_alb" {
    name                        = "${local.tag_header}external-alb"
    internal                    = false             # 외부 인터넷에서 접근 가능하도록 설정
    load_balancer_type          = "application"     # network / gateway / application
    security_groups             = [aws_security_group.std20_external_alb_sg.id]
    subnets                     = [
        aws_subnet.std20_pub_subnet[local.azs[0]].id,
        aws_subnet.std20_pub_subnet[local.azs[1]].id,
        aws_subnet.std20_pub_subnet[local.azs[2]].id
    ]

    tags = {
        Name = "${local.tag_header}external-alb"
    }
}

# ========================================================
# 로드밸런서에 리스너 추가
# ========================================================
resource "aws_lb_listener" "std20_external_alb_listener" {
    load_balancer_arn           = aws_lb.std20_external_alb.arn
    protocol                    = "HTTP"
    port                        = 80                # 사용자(외부/브라우저) 포트번호

    default_action {
        type                    = "forward"         # 대상 그룹 전달 / 리다이렉트 / 고정 응답(fixed response - error 대응 페이지) 등
        target_group_arn        = aws_lb_target_group.std20_web_instance_tg.arn
    }

    # 에러 유형에 대한 대응 페이지로 리다이렉트
    # default_action {
    #     type                    = "fixed-response"  # 고정 응답
    #     fixed_response {
    #         content_type        = "text/html"
    #         status_code         = 503
    #         message_body        = <<-EOF
    #             <html>
    #                 <head><title>Service Unavailable</title></head>
    #                 <body>
    #                     <h1>503 Service Unavailable</h1>
    #                     <p>현재 점검중입니다. 잠시 후 다시 시도해주세요.</p>
    #                 </body>
    #             </html>
    #         EOF
    #     }
    # }

    tags = {
        Name = "${local.tag_header}external-alb-listener"
    }
}

# ========================================================
# 리스너에 경로 규칙 추가
# ========================================================
resource "aws_lb_listener_rule" "std20_external_alb_listener_rule" {
    listener_arn               = aws_lb_listener.std20_external_alb_listener.arn
    priority                   = 100

    action {
        type                    = "forward"
        target_group_arn        = aws_lb_target_group.std20_web_instance_tg.arn
    }

    condition {
        path_pattern {
            values              = ["/api","/api/*"]
        }
    }

    tags = {
        Name = "${local.tag_header}external-alb-listener-rule"
    }
}

# 알아두면 좋은 명령어 :
output "std20_external_alb_dns_name" {
    value = aws_lb.std20_external_alb.dns_name
}

# ========================================================
# 대상 그룹에 대상 등록 : aws_lb_target_group_attachment
# ========================================================
# resource "aws_lb_target_group_attachment" "std20_web_instance_tg_attachment" {
#     target_group_arn            = aws_lb_target_group.std20_web_instance_tg.arn
#     target_id                   = aws_instance.std20_web_instance.id
#     port                        = 80
# }



# ========================================================
# Auto Scaling Group (ASG) 생성
# ========================================================
resource "aws_autoscaling_group" "std20_web_instance_asg" {
    name                        = "${local.tag_header}web-instance-asg"
    max_size                    = 3
    min_size                    = 1
    desired_capacity            = 1

    # 네트워크(subnet.id)
    vpc_zone_identifier         = [
        aws_subnet.std20_pub_subnet[local.azs[0]].id,
        aws_subnet.std20_pub_subnet[local.azs[1]].id,
        aws_subnet.std20_pub_subnet[local.azs[2]].id
    ]

    # 대상 그룹(ARN)
    target_group_arns           = [aws_lb_target_group.std20_web_instance_tg.arn]

    
    launch_template {
        id                      = aws_launch_template.std20_web_instance_lt.id
        version                 = "$Latest"         # Use the latest version of the launch template
    }

    # 헬스 체크
    health_check_type           = "EC2"             # EC2 인스턴스 상태 체크(기본값) -> ELB 로 변경 가능
    health_check_grace_period   = 300               # 헬스 체크 대기시간


    tag {
        key                     = "Name"
        value                   = "${local.tag_header}web-instance-asg"
        propagate_at_launch     = false
    }
}

# =========================================================
# ASG Policy 생성
# 인스턴스 수를 늘리는 정책(Scale Out Policy)
# =========================================================
resource "aws_autoscaling_policy" "std20_web_instance_asg_scale_out_policy" {
    name                        = "${local.tag_header}web-instance-asg-scale-out-policy"
    autoscaling_group_name      = aws_autoscaling_group.std20_web_instance_asg.name
    policy_type                 = "TargetTrackingScaling"

    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value               = 70.0     # 목표 CPU 사용률(%) - 70% 이상이면 인스턴스 수를 늘림
    }
}

# =========================================================
# ASG 예약 정책
# =========================================================
# resource "aws_autoscaling_schedule" "std20_web_instance_asg_scale_out_schedule" {
#     scheduled_action_name       = "${local.tag_header}web-instance-asg-scale-out-schedule"
#     autoscaling_group_name      = aws_autoscaling_group.std20_web_instance_asg.name

#     min_size                    = 2
#     max_size                    = 5
#     desired_capacity            = 4


#     # 실행 주기(Cron 표현식: 분 시 일 월 요일 연도)
#     # KST(UTC+9) 기준으로 실행됨. (AWS 콘솔에서는 UTC 기준으로 표시됨)

#     recurrence                  = "08 13 * * 1-5"        # 월~금 22시(UTC 기준)마다 실행
#     time_zone                   = "Asia/Seoul"           # KST 기준으로 실행되도록 설정
# }

resource "aws_autoscaling_schedule" "std20_web_instance_asg_scale_in_schedule" {
    scheduled_action_name       = "${local.tag_header}web-instance-asg-scale-in-schedule"
    autoscaling_group_name      = aws_autoscaling_group.std20_web_instance_asg.name

    min_size                    = 1
    max_size                    = 3
    desired_capacity            = 2

    # 실행 주기(Cron 표현식: 분 시 일 월 요일 연도)
    # KST(UTC+9) 기준으로 실행됨. (AWS 콘솔에서는 UTC 기준으로 표시됨)

    recurrence                  = "10 13 * * 1-5"        # 월~금 08시(UTC 기준)마다 실행
    time_zone                   = "Asia/Seoul"           # KST 기준으로 실행되도록 설정
}

