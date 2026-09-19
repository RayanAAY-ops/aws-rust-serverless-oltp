<img width="964" height="494" alt="Screenshot 2026-09-19 at 20 40 29" src="https://github.com/user-attachments/assets/62a496fe-41bf-4f25-8d20-beb94576f25f" />

# 1. Terraform state bucket (dev)
aws s3api create-bucket \
  --bucket rust-serverless-oltp-tfstate-dev \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket rust-serverless-oltp-tfstate-dev \
  --versioning-configuration Status=Enabled

# 2. Lambda deployment artifact bucket (bootstrap.zip uploads)
aws s3api create-bucket \
  --bucket aws-rust-serverless-oltp-lambda-artifacts \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1


brew install cargo-lambda/tap/cargo-lambda

cargo lambda build --release --arm64

aws s3 cp bootstrap.zip s3://aws-rust-serverless-oltp-lambda-artifacts/dev/8250ff9/bootstrap.zip

./build.sh 
