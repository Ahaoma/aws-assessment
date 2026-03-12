output "api_url" {
  description = "Base URL of the deployed API Gateway stage"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
