terraform {
  required_version = ">= 1.5.0"
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

#  Provider aliases ###################################################

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "archive" {}

# Shared locals #####################################################

locals {
  sns_topic_arn = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
}

# Cognito (us-east-1 only) ###############################################

module "cognito" {
  source = "./modules/cognito"

  candidate_email = var.candidate_email

  providers = {
    aws = aws.us_east_1
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# Regional stack – us-east-1
# ═════════════════════════════════════════════════════════════════════════════

module "vpc_us_east_1" {
  source = "./modules/vpc"

  providers = {
    aws = aws.us_east_1
  }
}

module "dynamodb_us_east_1" {
  source = "./modules/dynamodb"

  providers = {
    aws = aws.us_east_1
  }
}

module "ecs_us_east_1" {
  source = "./modules/ecs"

  sns_topic_arn     = local.sns_topic_arn
  candidate_email   = var.candidate_email
  candidate_repo    = var.candidate_repo
  subnet_id         = module.vpc_us_east_1.public_subnet_a_id
  security_group_id = module.vpc_us_east_1.ecs_security_group_id

  providers = {
    aws = aws.us_east_1
  }
}

module "lambda_us_east_1" {
  source = "./modules/lambda"

  sns_topic_arn           = local.sns_topic_arn
  candidate_email         = var.candidate_email
  candidate_repo          = var.candidate_repo
  dynamodb_table_name     = module.dynamodb_us_east_1.table_name
  dynamodb_table_arn      = module.dynamodb_us_east_1.table_arn
  ecs_cluster_arn         = module.ecs_us_east_1.cluster_arn
  ecs_task_definition_arn = module.ecs_us_east_1.task_definition_arn
  ecs_subnet_id           = module.vpc_us_east_1.public_subnet_a_id
  ecs_security_group_id   = module.vpc_us_east_1.ecs_security_group_id

  providers = {
    aws     = aws.us_east_1
    archive = archive
  }
}

module "api_gateway_us_east_1" {
  source = "./modules/api_gateway"

  cognito_user_pool_id     = module.cognito.user_pool_id
  cognito_client_id        = module.cognito.client_id
  greeter_invoke_arn       = module.lambda_us_east_1.greeter_invoke_arn
  greeter_function_name    = module.lambda_us_east_1.greeter_function_name
  dispatcher_invoke_arn    = module.lambda_us_east_1.dispatcher_invoke_arn
  dispatcher_function_name = module.lambda_us_east_1.dispatcher_function_name

  providers = {
    aws = aws.us_east_1
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# Regional stack – eu-west-1
# ═════════════════════════════════════════════════════════════════════════════

module "vpc_eu_west_1" {
  source = "./modules/vpc"

  providers = {
    aws = aws.eu_west_1
  }
}

module "dynamodb_eu_west_1" {
  source = "./modules/dynamodb"

  providers = {
    aws = aws.eu_west_1
  }
}

module "ecs_eu_west_1" {
  source = "./modules/ecs"

  sns_topic_arn     = local.sns_topic_arn
  candidate_email   = var.candidate_email
  candidate_repo    = var.candidate_repo
  subnet_id         = module.vpc_eu_west_1.public_subnet_a_id
  security_group_id = module.vpc_eu_west_1.ecs_security_group_id

  providers = {
    aws = aws.eu_west_1
  }
}

module "lambda_eu_west_1" {
  source = "./modules/lambda"

  sns_topic_arn           = local.sns_topic_arn
  candidate_email         = var.candidate_email
  candidate_repo          = var.candidate_repo
  dynamodb_table_name     = module.dynamodb_eu_west_1.table_name
  dynamodb_table_arn      = module.dynamodb_eu_west_1.table_arn
  ecs_cluster_arn         = module.ecs_eu_west_1.cluster_arn
  ecs_task_definition_arn = module.ecs_eu_west_1.task_definition_arn
  ecs_subnet_id           = module.vpc_eu_west_1.public_subnet_a_id
  ecs_security_group_id   = module.vpc_eu_west_1.ecs_security_group_id

  providers = {
    aws     = aws.eu_west_1
    archive = archive
  }
}

module "api_gateway_eu_west_1" {
  source = "./modules/api_gateway"

  cognito_user_pool_id     = module.cognito.user_pool_id
  cognito_client_id        = module.cognito.client_id
  greeter_invoke_arn       = module.lambda_eu_west_1.greeter_invoke_arn
  greeter_function_name    = module.lambda_eu_west_1.greeter_function_name
  dispatcher_invoke_arn    = module.lambda_eu_west_1.dispatcher_invoke_arn
  dispatcher_function_name = module.lambda_eu_west_1.dispatcher_function_name

  providers = {
    aws = aws.eu_west_1
  }
}
