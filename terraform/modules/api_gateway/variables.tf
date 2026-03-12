variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID (from cognito module)"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID (from cognito module)"
  type        = string
}

variable "greeter_invoke_arn" {
  description = "Invoke ARN of the Greeter Lambda (from lambda module)"
  type        = string
}

variable "greeter_function_name" {
  description = "Function name of the Greeter Lambda (from lambda module)"
  type        = string
}

variable "dispatcher_invoke_arn" {
  description = "Invoke ARN of the Dispatcher Lambda (from lambda module)"
  type        = string
}

variable "dispatcher_function_name" {
  description = "Function name of the Dispatcher Lambda (from lambda module)"
  type        = string
}
