output "greeter_invoke_arn" {
  value = aws_lambda_function.greeter.invoke_arn
}

output "greeter_function_name" {
  value = aws_lambda_function.greeter.function_name
}

output "dispatcher_invoke_arn" {
  value = aws_lambda_function.dispatcher.invoke_arn
}

output "dispatcher_function_name" {
  value = aws_lambda_function.dispatcher.function_name
}
