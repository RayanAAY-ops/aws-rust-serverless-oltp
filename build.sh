#!/usr/bin/env bash

# Requires: cargo-lambda (https://www.cargo-lambda.info/)
#   cargo install cargo-lambda

OUTPUT_ZIP="bootstrap.zip"
BUILD_DIR="target/lambda/aws-rust-serverless-oltp"


if ! command -v cargo-lambda >/dev/null 2>&1; then
  echo "error: cargo-lambda is required (cargo install cargo-lambda)" >&2
  exit 1
fi

echo "Building release binary for aarch64 (arm64) via cargo-lambda..."
cargo lambda build --release --arm64

# cargo lambda build places the packaged bootstrap binary here:

if [ ! -f "$BUILD_DIR/bootstrap" ]; then
  echo "error: expected $BUILD_DIR/bootstrap not found after build" >&2
  exit 1
fi

echo "Packaging $OUTPUT_ZIP..."
rm -f "$OUTPUT_ZIP"
(cd "$BUILD_DIR" && zip -j "$OUTPUT_ZIP" bootstrap)

echo "Built $BUILD_DIR/$OUTPUT_ZIP"
