// handler_fn/from_env are deprecated in favor of service_fn/aws_config::defaults;
// migrating is a separate task, tracked as a follow-up.
#![allow(deprecated)]

use std::collections::HashMap;

use aws_config::meta::region::RegionProviderChain;
use aws_sdk_dynamodb::Client;
use aws_sdk_dynamodb::types::AttributeValue;
use lambda_runtime::{Context, Error};
use serde::Deserialize;
use serde_json::{Value, json};
use uuid::Uuid;

#[derive(Debug, Deserialize, PartialEq)] // Debug and PartialEq for testing, Deserialize for JSON deserialization
pub struct MyEvent {
    pub item_name: String,
    pub price: f32,
}

pub async fn handler(event: Value, _context: Context) -> Result<Value, Error> {
    let my_event: MyEvent = serde_json::from_value(event)?;
    let item_id = Uuid::new_v4().to_string();

    // Set by Terraform (see terraform/lambda.tf) to the per-environment table
    // name, e.g. "shop-items-dev" / "-uat" / "-prod".
    let table_name = std::env::var("DYNAMODB_TABLE_NAME")
        .map_err(|_| "DYNAMODB_TABLE_NAME environment variable is not set")?;

    let region_provider = RegionProviderChain::default_provider().or_else("eu-west-1");
    let config = aws_config::from_env().region(region_provider).load().await;
    let client = Client::new(&config);

    client
        .put_item()
        .table_name(table_name)
        .set_item(Some(build_item(&item_id, &my_event)))
        .send()
        .await?;

    Ok(json!({"status": "success", "item_id": item_id}))
}

/// Builds the DynamoDB item (attribute map) for a new shop item.
/// Pure function: no I/O, so it's the one piece we can unit test.
pub fn build_item(item_id: &str, event: &MyEvent) -> HashMap<String, AttributeValue> {
    HashMap::from([
        (
            "item_id".to_string(),
            AttributeValue::S(item_id.to_string()),
        ),
        (
            "item_name".to_string(),
            AttributeValue::S(event.item_name.clone()),
        ),
        (
            "price".to_string(),
            AttributeValue::N(event.price.to_string()),
        ),
    ])
}
