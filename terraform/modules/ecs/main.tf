terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name

  # Build the SNS message string once so it is not double-encoded
  ecs_sns_message = jsonencode({
    email  = var.candidate_email
    source = "ECS"
    region = local.region
    repo   = var.candidate_repo
  })
}


# Cluster ################################################

resource "aws_ecs_cluster" "this" {
  name = "unleash-live-cluster-${local.region}"

  tags = { Project = "unleash-live-assessment" }
}

#IAM: execution role (ECR pull + CloudWatch logs) #######################################

resource "aws_iam_role" "task_execution" {
  name = "unleash-live-ecs-execution-${local.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = "unleash-live-assessment" }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM: task role (SNS publish) #################################

resource "aws_iam_role" "task" {
  name = "unleash-live-ecs-task-${local.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = "unleash-live-assessment" }
}

resource "aws_iam_role_policy" "task_sns_publish" {
  name = "unleash-live-ecs-sns-${local.region}"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = var.sns_topic_arn
    }]
  })
}

# ── Task definition #################################################

resource "aws_ecs_task_definition" "sns_publisher" {
  family                   = "unleash-live-sns-publisher-${local.region}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "sns-publisher"
    image = "amazon/aws-cli:latest"

    # aws sns publish exits 0 on success – container stops and task completes

    command = [
      "sns", "publish",
      "--topic-arn", var.sns_topic_arn,
      "--region", "us-east-1",
      "--message", local.ecs_sns_message
    ]


    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/unleash-live-${local.region}"
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "sns-publisher"
        "awslogs-create-group"  = "true"
      }
    }
  }])

  tags = { Project = "unleash-live-assessment" }
}
