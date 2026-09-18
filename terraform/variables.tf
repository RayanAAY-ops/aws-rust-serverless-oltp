variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment: dev, uat or prod"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "function_name" {
  description = "Base name for the Lambda function (environment is appended)"
  type        = string
  default     = "aws-rust-serverless-oltp"
}

variable "artifact_bucket" {
  description = "S3 bucket that holds built bootstrap.zip artifacts"
  type        = string
}

variable "artifact_key" {
  description = "S3 key of the bootstrap.zip to deploy (e.g. includes the CI commit SHA)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table used by the Lambda (shop-items)"
  type        = string
  default     = "shop-items"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention (days) for the Lambda's log group"
  type        = number
  default     = 30
}

variable "lambda_memory_mb" {
  description = "Memory allocated to the Lambda function, in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout, in seconds"
  type        = number
  default     = 10
}
