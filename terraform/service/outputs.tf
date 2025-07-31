output "lambda_function_arn" {
  value = aws_lambda_function.service_notifications.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.service_notifications.function_name
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution_role.arn
} 