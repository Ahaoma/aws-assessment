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

# HTTP API ################################################

resource "aws_apigatewayv2_api" "this" {
  name          = "unleash-live-api-${local.region}"
  protocol_type = "HTTP"

  tags = { Project = "unleash-live-assessment" }
}

#Cognito JWT authorizer #########################################

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# ── Integrations ############################

resource "aws_apigatewayv2_integration" "greeter" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.greeter_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "dispatcher" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.dispatcher_invoke_arn
  payload_format_version = "2.0"
}

# Routes #########################################################

resource "aws_apigatewayv2_route" "greet" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /greet"
  target             = "integrations/${aws_apigatewayv2_integration.greeter.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "dispatch" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /dispatch"
  target             = "integrations/${aws_apigatewayv2_integration.dispatcher.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Default auto-deploy stage ################################################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke both Lambdas ##################################

resource "aws_lambda_permission" "greeter" {
  statement_id  = "AllowAPIGatewayGreeter"
  action        = "lambda:InvokeFunction"
  function_name = var.greeter_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "dispatcher" {
  statement_id  = "AllowAPIGatewayDispatcher"
  action        = "lambda:InvokeFunction"
  function_name = var.dispatcher_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
