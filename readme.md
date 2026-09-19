cargo is similar to NPM in nodejs


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

./terraform/lambda-zipper/build.sh 


**Lines 1–3**
```rust
#![allow(deprecated)]
```
The `!` makes this an *inner* attribute — it applies to the whole enclosing item, here the entire crate (this file, since it's `lib.rs`), not just the next line. Compare to `#[derive(...)]` below on line 15, which is an *outer* attribute applying only to the item immediately after it. We use two AWS SDK functions later (`handler_fn` in `main.rs`, `from_env` on line 31) that the compiler wants to warn about as deprecated; this silences that specific warning crate-wide rather than sprinkling `#[allow(deprecated)]` on every call site.

**Lines 5–13: imports**
```rust
use std::collections::HashMap;
use aws_config::meta::region::RegionProviderChain;
use aws_sdk_dynamodb::Client;
use aws_sdk_dynamodb::types::AttributeValue;
use lambda_runtime::{Context, Error};
use serde::Deserialize;
use serde_json::{Value, json};
use uuid::Uuid;
```
Equivalent to Python's `from x import y` — brings names into scope so you write `HashMap` instead of `std::collections::HashMap` everywhere. `{Context, Error}` and `{Value, json}` are just grouped imports from the same module, purely cosmetic.

Notably, `AttributeValue` is DynamoDB's own tagged-union type for values (`S` for string, `N` for number-as-string, etc.) — this is the same concept as boto3's `{"S": "..."}`/`{"N": "..."}` dict wrapping in Python, except here it's a real Rust `enum`, so the compiler enforces you use the right variant instead of it being a stringly-typed dict key you could typo.

**Lines 15–19: the input schema**
```rust
#[derive(Debug, Deserialize, PartialEq)]
pub struct MyEvent {
    pub item_name: String,
    pub price: f32,
}
```
`derive` is compile-time codegen — it writes trait implementations for you rather than you hand-coding them. Think of it like a dataclass decorator, but the generated code is fully typed and inlined, not reflection-based at runtime:
- `Debug` → lets you `{:?}`-print the struct for logging/debugging.
- `Deserialize` → generates the actual JSON-parsing logic for this exact struct shape, from the `serde` crate. This is the Rust equivalent of a Pydantic model or a dataclass + `json.loads` combo, except the parsing code is generated at compile time (zero runtime reflection cost), and it fails at compile time if the struct can't map cleanly.
- `PartialEq` → generates `==` comparison, field-by-field. Rust doesn't give you structural equality for free; you opt in.

`pub` on the struct and each field means "visible outside this file/crate" — this is what lets `tests/build_item.rs` and `tests/event_deserialization.rs` (separate compilation units) actually see and construct `MyEvent`.

**Line 21: the handler signature**
```rust
pub async fn handler(event: Value, _context: Context) -> Result<Value, Error>
```
- `async fn` — this function doesn't block a thread while waiting on I/O (network calls to AWS); think of it like an `async def` in Python, but Rust's async has no runtime by default — it needs an executor (that's what `tokio` in `main.rs` provides).
- `event: Value` — `Value` is `serde_json`'s dynamically-typed JSON value (like Python's `dict`/`json` object before you've validated its shape). We haven't committed to `MyEvent`'s shape yet at the function boundary — that's what line 22 does.
- `_context: Context` — Lambda invocation metadata (request ID, remaining time budget, etc.). The leading underscore is Rust's convention for "parameter required by the signature/trait, but I'm not using it" — suppresses the "unused variable" warning.
- `Result<Value, Error>` — Rust has no exceptions. Every fallible operation returns `Result<T, E>`, an enum with two variants: `Ok(T)` or `Err(E)`. The caller (`lambda_runtime`) is forced by the type system to handle both cases — you cannot "forget" to check for an error the way you can in Python or Go before someone remembers to check `if err != nil`.

**Line 22: parse + the `?` operator**
```rust
let my_event: MyEvent = serde_json::from_value(event)?;
```
`serde_json::from_value` returns `Result<MyEvent, serde_json::Error>` — attempt to parse `event` (untyped JSON) into the `MyEvent` shape. The `?` at the end is sugar for: "if this is `Err(e)`, immediately `return Err(e.into())` from the whole function; if `Ok(v)`, unwrap to `v` and keep going." It's like an early-return-on-exception, but explicit and visible at every call site — no invisible stack unwinding. This is also why `handler`'s return type is `Result<Value, Error>`: `?` can only be used in a function whose error type is compatible with the error being propagated.

**Line 23**
```rust
let item_id = Uuid::new_v4().to_string();
```
Generates a random UUID (v4 = fully random, not time-based), then converts it to its string representation. This is your DynamoDB partition key — same idea as generating a UUID for a primary key in any OLTP system before insert.

**Lines 27–28: reading required config with a real error message**
```rust
let table_name = std::env::var("DYNAMODB_TABLE_NAME")
    .map_err(|_| "DYNAMODB_TABLE_NAME environment variable is not set")?;
```
`std::env::var` returns `Result<String, VarError>` — `Err` if the env var is unset or not valid UTF-8. `.map_err(|_| "...")` transforms whatever the original error was into a plain `&str` message instead — we don't care about the specific `VarError` variant, just that it failed, so we replace it with something readable that'll show up in your Lambda logs. `|_|` is a closure (anonymous function) taking one argument we ignore (`_`) and returning the string literal. Then `?` does the same early-return-on-error as before. This is the exact fix from earlier in this conversation — reading the table name Terraform injects via the Lambda's environment, instead of hardcoding it.

**Lines 30–32: building the AWS client**
```rust
let region_provider = RegionProviderChain::default_provider().or_else("eu-west-1");
let config = aws_config::from_env().region(region_provider).load().await;
let client = Client::new(&config);
```
- `RegionProviderChain` — tries several strategies in order to determine which AWS region to use (env var, config file, instance metadata...), falling back to the hardcoded `"eu-west-1"` if none of them resolve. Same pattern as boto3's region resolution chain.
- `.load().await` — this is actually async I/O (may read files, hit the EC2/Lambda metadata endpoint) — hence `.await`, suspending this function until it completes, without blocking the whole thread.
- `Client::new(&config)` — the `&` is a *borrow*: we're lending a reference to `config` to the client constructor rather than handing over ownership. This matters in Rust specifically because ownership is tracked at compile time — if we'd moved `config` in, we couldn't use it again below. Passing by reference here means whoever calls this could still reuse `config` afterward (the comment about this in the earlier draft of `main.rs` — "we borrow so we don't transfer ownership" — was exactly this concept, just verbose).

**Lines 34–39: the actual write**
```rust
client
    .put_item()
    .table_name(table_name)
    .set_item(Some(build_item(&item_id, &my_event)))
    .send()
    .await?;
```
Builder pattern — same idea as chaining `.filter().select()` in a query builder, or boto3's `client.put_item(TableName=..., Item=...)` but split into fluent method calls, each returning `self` until `.send()` actually fires the request. `Some(...)` wraps the item map in Rust's `Option` type (`Some(x)` vs `None`) — because this particular SDK field is optional in general, even though we're always supplying it here. `.send().await?` — async network call, `?` propagates any AWS-side error (throttling, permission denied, table missing — exactly the bug you hit earlier) straight out of `handler`.

**Line 41: the response**
```rust
Ok(json!({"status": "success", "item_id": item_id}))
```
`json!` is a macro (compile-time code generation, denoted by the `!`) that builds a `serde_json::Value` from JSON-like syntax inline — convenient shorthand instead of manually constructing a `HashMap`. Wrapped in `Ok(...)` because the function's return type demands a `Result`, and this is the success path.

**Lines 44–61: `build_item`**
```rust
pub fn build_item(item_id: &str, event: &MyEvent) -> HashMap<String, AttributeValue> {
```
Notice: no `async`, and both parameters are borrowed (`&str`, `&MyEvent`) rather than owned — this function only *reads* the data to construct a new map, it never needs to own or mutate the originals. That's precisely what makes it a **pure function**: given the same inputs, always the same output, no I/O, no side effects — which is exactly why it's the one thing pulled out into `tests/build_item.rs` as a unit-testable seed, separate from everything touching the network.

```rust
HashMap::from([
    ("item_id".to_string(), AttributeValue::S(item_id.to_string())),
    ...
])
```
`HashMap::from([...])` builds a map directly from an array of `(key, value)` tuples — like `dict([(k1, v1), (k2, v2)])` in Python. `.to_string()` converts a borrowed `&str` into an owned `String` (the map needs to own its keys, it can't borrow from a caller who might drop the value later). `AttributeValue::S(...)` / `::N(...)` are enum variant constructors — `S` for the "String" variant, `N` for "Number" (DynamoDB numbers are transmitted as strings over the wire, hence `.to_string()` on the `f32` price too).

## The one thing worth internalizing

The whole file's shape — `build_item` as pure/sync/testable, `handler` as the thin async/I/O wrapper around it — is the Rust-idiomatic version of a pattern you already know well from data engineering: separate your transformation logic from your I/O so the transformation is unit-testable without mocking a database. Rust's borrow checker just makes that separation *enforced*, not just a style convention — `build_item` literally cannot accidentally make a network call, because it has no access to any client or `await` point.