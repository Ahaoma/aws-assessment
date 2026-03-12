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
}

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs-${local.region}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Project = "unleash-live-assessment" }
}
