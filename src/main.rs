// handler_fn is deprecated in favor of service_fn; migrating is a separate
// task, tracked as a follow-up.
#![allow(deprecated)]

use aws_rust_serverless_oltp::handler;
use lambda_runtime::{Error, handler_fn};

// tokio directive, expected by the lambda, make our main function async
#[tokio::main]
async fn main() -> Result<(), Error> {
    let func = handler_fn(handler);
    lambda_runtime::run(func).await?;
    Ok(())
}
