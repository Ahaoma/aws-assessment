variable "candidate_email" {
  description = "Your email address (used for Cognito test user and SNS payloads)"
  type        = string
}

variable "candidate_repo" {
  description = "Your public GitHub repo URL, e.g. https://github.com/youruser/aws-assessment"
  type        = string
}
