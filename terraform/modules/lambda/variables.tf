variable "sns_topic_arn" {
  description = "ARN of the Unleash live verification SNS topic"
  type        = string
}

variable "candidate_email" {
  description = "Candidate email used in SNS payload"
  type        = string
}

variable "candidate_repo" {
  description = "Candidate GitHub repo URL used in SNS payload"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the regional DynamoDB table (from dynamodb module)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the regional DynamoDB table (from dynamodb module)"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster (from ecs module)"
  type        = string
}

variable "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition (from ecs module)"
  type        = string
}

variable "ecs_subnet_id" {
  description = "Subnet ID to launch ECS Fargate tasks into (from vpc module)"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS Fargate tasks (from vpc module)"
  type        = string
}
