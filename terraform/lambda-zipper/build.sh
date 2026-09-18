#!/usr/bin/env bash
# Builds the Rust Lambda binary and packages it as bootstrap.zip for
# provided.al2023 (arm64), matching terraform/lambda.tf's architectures/runtime.
#
# Usage: terraform/lambda-zipper/build.sh [output_zip_path]
#   output_zip_path defaults to ./bootstrap.zip (relative to repo root)
#
# Requires: cargo-lambda (https://www.cargo-lambda.info/)
#   cargo install cargo-lambda

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Resolve to an absolute path up front: a relative $1 must stay relative to
# the caller's cwd, not to $REPO_ROOT or $BUILD_DIR (both of which we cd into
# below) — otherwise the zip silently lands somewhere the caller never asked for.
if [ -n "${1:-}" ]; then
  case "$1" in
    /*) OUTPUT_ZIP="$1" ;;
    *) OUTPUT_ZIP="$(pwd)/$1" ;;
  esac
else
  OUTPUT_ZIP="$REPO_ROOT/bootstrap.zip"
fi

cd "$REPO_ROOT"

if ! command -v cargo-lambda >/dev/null 2>&1; then
  echo "error: cargo-lambda is required (cargo install cargo-lambda)" >&2
  exit 1
fi

echo "Building release binary for aarch64 (arm64) via cargo-lambda..."
# Explicit musl target rather than --arm64: cargo-lambda's --arm64 shorthand
# maps to aarch64-unknown-linux-gnu.2.26, whose target spec passes
# --fix-cortex-a53-843419 to the linker. Zig's bundled lld doesn't support
# that flag and the build fails. musl's target spec has no such flag, and
# static musl binaries run fine on Lambda's provided.al2023 (arm64).
cargo lambda build --release --target aarch64-unknown-linux-musl

# cargo lambda build places the packaged bootstrap binary here:
BUILD_DIR="target/lambda/aws-rust-serverless-oltp"

if [ ! -f "$BUILD_DIR/bootstrap" ]; then
  echo "error: expected $BUILD_DIR/bootstrap not found after build" >&2
  exit 1
fi

echo "Packaging $OUTPUT_ZIP..."
rm -f "$OUTPUT_ZIP"
(cd "$BUILD_DIR" && zip -j "$OUTPUT_ZIP" bootstrap)

echo "Built $OUTPUT_ZIP"
