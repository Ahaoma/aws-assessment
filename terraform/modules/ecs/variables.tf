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

variable "subnet_id" {
  description = "Public subnet ID for Fargate task networking"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for Fargate tasks"
  type        = string
}
