# Unleash live – AWS DevOps Engineer Assessment

End-to-end IaC solution for the Unleash live technical assessment.  
This project provisions a multi-region AWS compute stack secured by a centralised Amazon Cognito User Pool, with automated testing and a full CI/CD pipeline.
---

## Architecture Overview

Cognito (us-east-1)
      │
      ▼
API Gateway (per region)
   │           │
 /greet      /dispatch
   │           │
Lambda      Lambda
   │           │
DynamoDB    ECS RunTask
   │           │
SNS         SNS

## Repository Structure

```
aws-assessment/
├── terraform/
│   ├── main.tf                  # Root – wires Cognito + two compute modules
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── cognito/                 # Cognito User Pool, Client, test user
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── modules/
│       ├── vpc/                 # VPC, subnets, IGW, route tables, SG
│       │   ├── main.tf
│       │   └── outputs.tf
│       ├── dynamodb/            # DynamoDB GreetingLogs table
│       │   ├── main.tf
│       │   └── outputs.tf
│       ├── ecs/                 # ECS cluster, task definition, IAM roles
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── lambda/              # Greeter & Dispatcher functions, IAM role
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── api_gateway/         # HTTP API, Cognito authorizer, routes, stage
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── lambdas/
│   ├── greeter/
│   │   └── lambda_function.py   # Writes to DynamoDB + publishes to SNS
│   └── dispatcher/
│       └── lambda_function.py   # Calls ECS RunTask
├── scripts/
│   └── test.py                  # End-to-end test script
├── .github/workflows/
│   └── deploy.yml               # GitHub Actions CI/CD pipeline
└── README.md
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.5 |
| Python | ≥ 3.12 |
| AWS CLI | v2 |
| AWS account with sufficient IAM permissions | – |

---

## Manual Deployment

### 1 – Clone & configure

```bash
git clone https://github.com/Ahaoma/aws-assessment.git
cd aws-assessment
```

> No Lambda dependency installation is required. Both Lambdas use only `boto3`, which is built into the AWS Lambda Python 3.12 runtime.


```

### 2 – Configure AWS credentials

```bash
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_DEFAULT_REGION=us-east-1
# or: aws configure --profile unleash-live
```

### 3 – Deploy

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform will output:

```
cognito_user_pool_id  = "us-east-1_XXXXXXXXX"
cognito_client_id     = "XXXXXXXXXXXXXXXXXXXXXXXXXX"
api_url_us_east_1     = "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com"
api_url_eu_west_1     = "https://xxxxxxxxxx.execute-api.eu-west-1.amazonaws.com"
```

---

## Setting the Cognito Test User Password

Terraform creates the user with a temporary password (`Interview123!`).  
To set the password permanently via CLI before running the test script:

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username <your@email.com> \
  --password 'YourNewPassword1!' \
  --permanent \
  --region us-east-1
```

---

## Running the Test Script

Install dependencies:

```bash
pip install boto3 requests
```

Run:

```bash
python ../scripts/test.py \
  --user-pool-id  <cognito_user_pool_id> \
  --client-id     <cognito_client_id> \
  --username      your@email.com \
  --password      'YourPassword1!' \
  --api-us        <api_url_us_east_1> \
  --api-eu        <api_url_eu_west_1>
```

### Expected output

```
Step 1: Authenticating with Cognito (us-east-1)...
JWT retrieved successfully.

Step 2: Concurrently calling /greet in both regions...

/greet results:
  [us-east-1]
    Status  : 200
    Latency : 112.34 ms
    Region  : us-east-1
    Assert  : PASS (expected 'us-east-1', got 'us-east-1')

  [eu-west-1]
    Status  : 200
    Latency : 198.76 ms
    Region  : eu-west-1
    Assert  : PASS (expected 'eu-west-1', got 'eu-west-1')

  Geographic latency – us-east-1: 112.34 ms | eu-west-1: 198.76 ms | delta: 86.42 ms

Step 3: Concurrently calling /dispatch in both regions...

/dispatch results:
  [us-east-1]
    Status  : 200
    Latency : 543.21 ms
    Region  : us-east-1
    Assert  : PASS (expected 'us-east-1', got 'us-east-1')

  [eu-west-1]
    Status  : 200
    Latency : 621.10 ms
    Region  : eu-west-1
    Assert  : PASS (expected 'eu-west-1', got 'eu-west-1')

All assertions passed.
```

---

## CI/CD Pipeline

The `.github/workflows/deploy.yml` pipeline runs on every push to `main`:

| Job | Trigger | Steps |
|-----|---------|-------|
| **lint-validate** | all pushes / PRs | `terraform fmt`, `terraform validate`, Python syntax check (`py_compile`) |
| **security-scan** | after lint | Checkov IaC static analysis |
| **plan** | push to `main` | `terraform plan`, uploads plan artifact |
| **deploy** | after plan (manual approval) | `terraform apply` |
| **test** | after deploy | runs `scripts/test.py` end-to-end |

---

## Multi-Region Provider Design

The multi-region strategy uses **Terraform provider aliases** defined in `terraform/main.tf`:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}
```

The **`modules/compute`** module is instantiated twice — once per region — with its provider set via `providers = { aws = aws.us_east_1 }` and `aws.eu_west_1` respectively.  
Inside the module, `data.aws_region.current` resolves dynamically so all resource names, environment variables, and SNS payloads are automatically region-scoped with zero duplication.

The **Cognito module** is deployed once in `us-east-1` only, and its `user_pool_arn`, `user_pool_id`, and `client_id` outputs are passed into both compute modules as variables. The API Gateway JWT authoriser in each region points back to the single Cognito issuer URL (`cognito-idp.us-east-1.amazonaws.com/<pool-id>`), enabling true centralised authentication across regions.

---

## Cost Optimisation Notes

- **No NAT Gateway**: Fargate tasks are placed in public subnets with `assignPublicIp: ENABLED`, eliminating ~$32/month per NAT Gateway.
- **DynamoDB PAY_PER_REQUEST**: No provisioned capacity waste.
- **Lambda**: Billed only on invocation; no idle cost.
- **ECS Fargate tasks**: Ephemeral, exit after one SNS publish.

---

## Teardown

Once the SNS payloads have been sent and verified, destroy all infrastructure immediately:

```bash
cd terraform
terraform destroy \
  -var="candidate_email=your@email.com" \
  -var="candidate_repo=https://github.com/<youruser>/aws-assessment"
```

Type `yes` when prompted.
