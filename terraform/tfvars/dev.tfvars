environment    = "dev"
aws_region     = "eu-west-1"
function_name  = "aws-rust-serverless-oltp"

# CHANGE_ME: bucket that CI uploads bootstrap.zip artifacts into.
artifact_bucket = "aws-rust-serverless-oltp-lambda-artifacts"

# artifact_key is intentionally left unset here — CI passes it per-build via
# `-var artifact_key=...` (e.g. dev/<git-sha>/bootstrap.zip) so each deploy
# points at the exact artifact that was just built and tested.

dynamodb_table_name    = "shop-items"
log_retention_days     = 14
lambda_memory_mb       = 128
lambda_timeout_seconds = 10
