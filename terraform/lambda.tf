# --- DynamoDB table used by the handler (see src/main.rs: table_name("shop-items")) ---

resource "aws_dynamodb_table" "shop_items" {
  name         = local.full_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }
}

# --- Lambda function: zip package on provided.al2023 (custom Rust runtime) ---
# IAM role is defined ourselves in role.tf and passed in below, instead of
# letting the module create one; the module still manages the log group.

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = local.full_function_name

  runtime = "provided.al2023"
  handler = "bootstrap" # ignored by provided.al2023, but required by the API

  architectures = ["arm64"] # cheaper + faster cold start; build must target aarch64

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  # We build & zip ourselves (terraform/lambda-zipper/build.sh) and upload to
  # S3 in CI; the module should not try to build the package itself.
  create_package = false
  s3_existing_package = {
    bucket = var.artifact_bucket
    key    = var.artifact_key
  }

  cloudwatch_logs_retention_in_days = var.log_retention_days

  environment_variables = {
    RUST_LOG            = "info"
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.shop_items.name
  }

  # Use the role defined in role.tf instead of having the module create one.
  create_role = false
  lambda_role = aws_iam_role.lambda_exec.arn

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb,
  ]
}
