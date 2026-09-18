environment   = "prod"
aws_region    = "eu-west-1"
function_name = "aws-rust-serverless-oltp"

# CHANGE_ME: bucket that CI uploads bootstrap.zip artifacts into.
artifact_bucket = "CHANGE_ME-lambda-artifacts"

# artifact_key is passed by CI at plan/apply time via -var artifact_key=...

dynamodb_table_name    = "shop-items"
log_retention_days     = 90
lambda_memory_mb       = 256
lambda_timeout_seconds = 10
