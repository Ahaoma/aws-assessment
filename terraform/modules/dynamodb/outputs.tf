output "table_name" {
  value = aws_dynamodb_table.greeting_logs.name
}

output "table_arn" {
  value = aws_dynamodb_table.greeting_logs.arn
}
