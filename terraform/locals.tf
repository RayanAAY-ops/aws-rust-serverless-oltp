locals {
  # e.g. "aws-rust-serverless-oltp-dev"
  full_function_name = "${var.function_name}-${var.environment}"

  # e.g. "shop-items-dev" so dev/uat/prod don't share a table
  full_table_name = "${var.dynamodb_table_name}-${var.environment}"
}
