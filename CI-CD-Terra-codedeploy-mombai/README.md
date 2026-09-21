# 원본 구조 유지 — 뭄바이 CodeDeploy / CodePipeline 실습

처음 첨부한 CI-CD-Terra(1).zip에서 다시 구성했습니다.
기존 modules의 8개 모듈과 templates/ec2-user-data.sh는 원본 그대로입니다.
추가한 modules/cicd/main.tf에 사용자가 제공한 1~7번 코드가 들어 있습니다.
이전 답변에서 만든 축소 네트워크, 별도 배포 예제, enable_pipeline 옵션, local backend는 사용하지 않습니다.

## 변경한 부분

| 파일 | 수정 |
|---|---|
| main.tf | network/security 유지; compute/storage/eks 호출 주석; 기존 asg/database/endpoints 주석 유지; cicd 호출 추가 |
| variables.tf | 기본 리전과 3개 AZ를 ap-south-1로 변경; GitHub 변수 2개 추가 |
| terraform.tfvars | region을 ap-south-1로 변경; 제공 코드의 GitHub 저장소/브랜치 값 추가 |
| locals.tf | storage를 참조하던 web_user_data만 주석 |
| data.tf | 이번 구성에서 쓰지 않는 기존 조회를 주석 |
| outputs.tf | 비활성 모듈 관련 출력을 주석; 새 CI/CD 출력 추가 |
| moved.tf | 기존 홍콩 state용 이동 선언을 주석 |
| providers.tf | 기존 S3 backend 유지, key만 CI-CD-Terra-Mumbai/terraform.tfstate로 분리 |
| modules/cicd/ | 사용자 코드와 모듈 입력/출력/Provider 선언 추가 |

원본의 VPC 10.0.0.0/16, Public/Private/Cluster 각 3개 서브넷, NAT Gateway,
보안그룹 구성, std20-cicd 접두사를 유지했습니다. 불필요한 보안그룹까지 지우면 원본
모듈 수정이 커지므로 이번 버전에서는 network/security 모듈 내부를 수정하지 않았습니다.
다른 원본 모듈 파일도 삭제하지 않았지만, 호출이 주석이므로 생성하지 않습니다.

## 제공한 코드에서 꼭 바꾼 부분

- modules/cicd/locals.tf에서 루트 tag_header를 연결해 local.tag_header 표현 유지
- 고정 sg-... 두 개 대신 원본 web_sg_id/internal_ssh_sg_id 연결
- VPC 구분 없는 태그 조회 대신 원본 cluster_subnet_ids 연결 (같은 cluster 서브넷 목적)
- GitHub 저장소/브랜치만 terraform.tfvars에서 입력하도록 연결
- 누락된 Connection 사용 권한 2개와 S3 버킷 위치/ACL 조회 권한 추가
- IAM 정책과 NAT 라우팅 준비 후 리소스가 만들어지도록 depends_on 추가

t3.micro, ASG 최소1/유지2/최대3, $Latest, Amazon Linux 2023,
인라인 User Data, 관리형 IAM 정책, AllAtOnce, Source→Deploy, force_destroy=true는 유지했습니다.
CodeDeploy Agent 설치 URL은 사용자가 보낸 코드부터 이미 ap-south-1이므로 그대로입니다.
CodeBuild 권한은 제공 코드대로 남겼지만 실제 CodeBuild 단계나 Docker 이미지 빌드는 없습니다.
제공 코드에 없던 SSH 키, ALB, 자동 롤백, 새로운 앱 배포 스크립트는 추가하지 않았습니다.

## 1. 별도 폴더에 압축 풀기

기존 적용 폴더 위에 덮어쓰지 마세요. 압축의 CI-CD-Terra 폴더를 별도 위치에서 사용합니다.
.terraform과 terraform.tfstate는 가져오지 않습니다.

이전 버전을 이미 적용했다면 이 파일은 그 상태를 이어받는 업데이트가 아닙니다.
이전 실습 리소스는 기존 폴더/state로 관리하고, 이번 구성은 별도 state로 생성합니다.
같은 이름의 IAM Role 등이 이미 있는 경우에는 해당 리소스의 관리 state를 먼저 확인하세요.

## 2. terraform.tfvars 수정

```hcl
region = "ap-south-1"

github_repository = "본인GitHub계정/실제저장소"
github_branch     = "main"
```

파일의 csjin21c/aws-cicd-pipeline은 제공 코드의 예제를 유지한 값입니다.
반드시 접근 가능한 실제 저장소로 바꾸세요. URL 전체를 넣지 않습니다.

원본의 key_name/eks_version/db_name/db_username도 남아 있지만 관련 모듈이 꺼져 있어
이번 배포에는 쓰이지 않습니다. 새 Launch Template에는 제공 코드대로 key_name이 없습니다.

## 3. backend 확인

```hcl
backend "s3" {
  bucket       = "std20-terraform-state-bucket"
  key          = "CI-CD-Terra-Mumbai/terraform.tfstate"
  region       = "ap-east-1"
  encrypt      = true
  use_lockfile = true
}
```

여기의 ap-east-1은 원본 상태 버킷의 위치입니다. EC2/VPC/CodePipeline 배포 리전은
terraform.tfvars의 ap-south-1입니다. 버킷을 옮기지 않았다면 backend region은 바꾸지 않습니다.
기존 버킷이 존재하고 새 key 및 .tflock에 접근 권한이 있어야 합니다.
해당 key를 이미 사용 중이라면 다른 새 경로를 선택하세요.
원본 CI-CD-Terra/terraform.tfstate로 되돌리면 기존 환경 삭제/교체가 계획될 수 있습니다.

## 4. 적용 — PC PowerShell, CI-CD-Terra 최상위에서

```powershell
aws sts get-caller-identity
terraform init
terraform validate
terraform plan -out=mumbai.tfplan
terraform apply mumbai.tfplan
terraform output
```

Terraform 1.10 이상이 필요합니다. 첫 신규 plan은 추가만 있어야 합니다.
기존 리소스 삭제/교체 또는 state 마이그레이션이 나오면 진행 전에 폴더와 backend를 확인하세요.
실행 계정에는 관련 AWS 리소스 생성 권한과 IAM PassRole 권한이 필요합니다.

## 5. GitHub 연결 승인과 파이프라인 재실행

이번 버전은 제공 코드와 동일하게 첫 apply에서 Pipeline까지 생성합니다.
GitHub Connection이 아직 Pending이면 초기 Source 실행은 실패할 수 있습니다.
AWS 콘솔 리전을 뭄바이로 맞추고 Developer Tools → Settings → Connections에서
std20-cicd-github-connection을 열어 GitHub 인증과 저장소 접근 승인을 완료하세요.
Connection이 AVAILABLE인지 확인합니다.

```powershell
$connectionArn = terraform output -raw connection_arn
aws codeconnections get-connection --connection-arn $connectionArn --region ap-south-1 --query "Connection.ConnectionStatus" --output text
```

이 구성은 인프라 생성 코드입니다. 실제 Source 저장소 루트에 appspec.yml과
그 파일에서 호출하는 배포 스크립트가 있어야 CodeDeploy 배포가 성공합니다.
이번 압축에는 임의의 Nginx 앱이나 배포 스크립트를 추가하지 않았습니다.
Terraform 파일만 있는 저장소를 연결하면 앱 배포까지 자동 완성되지는 않습니다.

## 6. EC2 Agent 확인

```powershell
$asgName = terraform output -raw asg_name
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgName --region ap-south-1 --query "AutoScalingGroups[0].Instances[].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}" --output table
aws ssm describe-instance-information --region ap-south-1 --query "InstanceInformationList[].{ID:InstanceId,Status:PingStatus}" --output table
aws ssm start-session --target i-실제인스턴스ID --region ap-south-1
```

Session Manager plugin이 PC에 필요합니다. SSM에서 Online으로 표시된 뒤 접속하세요.
AL2023 AMI의 SSM Agent와 원본 코드의 AmazonSSMManagedInstanceCore 정책을 이용합니다.
생성 직후 EC2가 InService여도 User Data 설치는 아직 진행 중일 수 있습니다.

인스턴스 안에서:

```bash
sudo cloud-init status --wait
sudo systemctl status docker codedeploy-agent
sudo tail -n 100 /var/log/cloud-init-output.log
```

두 ASG 인스턴스의 Agent가 정상인지 확인한 뒤 PC PowerShell에서:

```powershell
$pipelineName = terraform output -raw pipeline_name
aws codepipeline start-pipeline-execution --name $pipelineName --region ap-south-1
aws codepipeline get-pipeline-state --name $pipelineName --region ap-south-1
```

제공 코드의 User Data는 원문 그대로여서 설치 실패 시에도 후속 명령이 진행될 수 있습니다.
Agent 상태와 cloud-init-output.log를 보고 실제 설치 성공을 확인하세요.

## 접속 및 정리

원본 web SG는 ALB SG에서 오는 웹 트래픽을 허용하지만 이번에는 ALB를 만들지 않습니다.
ASG는 공인 IP 없는 cluster 서브넷에 있어 PC에서 웹/SSH 직접 접속은 되지 않습니다.
웹 앱 배포 후 SSM 안에서 curl로 확인하거나 SSM 포트 포워딩을 사용하세요.
ALB SG가 생성되어 있어도 ALB 자체가 생성되는 것은 아닙니다.

실습 종료 시 이번 폴더에서 terraform plan -destroy로 대상 확인 후 terraform destroy를 실행하세요.
NAT Gateway와 EC2 등은 유지 비용이 발생하고, force_destroy=true인 아티팩트 버킷 내용도 삭제됩니다.

## 검증 범위

원본 modules 8개와 templates의 파일 내용이 동일한지 비교했습니다.
HCL 파싱, 활성 참조/모듈 연결, 새 모듈 Terraform 포맷, User Data 셸 문법을 확인했습니다.
이 환경에서 Provider의 Unix socket 실행이 차단되어 전체 terraform validate는 완료하지 못했습니다.
AWS plan/apply 및 GitHub/CodeDeploy 실제 배포는 수행하지 않았습니다.

공식 참고:
- https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodestarConnectionSource.html
- https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-linux.html
- https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file.html
