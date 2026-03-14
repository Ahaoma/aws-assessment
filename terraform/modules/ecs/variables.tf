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

