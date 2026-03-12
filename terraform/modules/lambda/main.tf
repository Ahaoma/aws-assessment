terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

#IAM role shared by both Lambda functions #####################################

resource "aws_iam_role" "lambda_exec" {
  name = "unleash-live-lambda-exec-${local.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = "unleash-live-assessment" }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "unleash-live-lambda-policy-${local.region}"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.dynamodb_table_arn
      },
      {
        Sid      = "SNS"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.sns_topic_arn
      },
      {
        Sid    = "ECSRunTask"
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Zip Lambda source files #################################

data "archive_file" "greeter" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/greeter/lambda_function.py"
  output_path = "${path.module}/greeter.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.root}/../lambdas/dispatcher/lambda_function.py"
  output_path = "${path.module}/dispatcher.zip"
}

# Lambda 1: Greeter ################################################
resource "aws_lambda_function" "greeter" {
  function_name    = "unleash-live-greeter-${local.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.greeter.output_path
  source_code_hash = data.archive_file.greeter.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE   = var.dynamodb_table_name
      SNS_TOPIC_ARN    = var.sns_topic_arn
      CANDIDATE_EMAIL  = var.candidate_email
      CANDIDATE_REPO   = var.candidate_repo
      EXECUTING_REGION = local.region
    }
  }

  tags = { Project = "unleash-live-assessment" }
}

# Lambda 2: Dispatcher ###########################################
resource "aws_lambda_function" "dispatcher" {
  function_name    = "unleash-live-dispatcher-${local.region}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.dispatcher.output_path
  source_code_hash = data.archive_file.dispatcher.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      ECS_CLUSTER_ARN         = var.ecs_cluster_arn
      ECS_TASK_DEFINITION_ARN = var.ecs_task_definition_arn
      ECS_SUBNET_ID           = var.ecs_subnet_id
      ECS_SECURITY_GROUP_ID   = var.ecs_security_group_id
      EXECUTING_REGION        = local.region
    }
  }

  tags = { Project = "unleash-live-assessment" }
}
