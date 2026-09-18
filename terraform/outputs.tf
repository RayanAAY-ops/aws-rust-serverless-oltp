output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = module.lambda.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table backing this environment"
  value       = aws_dynamodb_table.shop_items.name
}
