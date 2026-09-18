// handler_fn/from_env are deprecated in favor of service_fn/aws_config::defaults;
// migrating is a separate task, tracked as a follow-up.
#![allow(deprecated)]

use std::collections::HashMap;

use aws_config::meta::region::RegionProviderChain;
use aws_sdk_dynamodb::Client;
use aws_sdk_dynamodb::types::AttributeValue;
use lambda_runtime::{Context, Error, handler_fn};
use serde::Deserialize;
use serde_json::{Value, json};
use uuid::Uuid;

const TABLE_NAME: &str = "shop-items";

// tokio directive, expected by the lambda, make our main function async
#[tokio::main]
async fn main() -> Result<(), Error> {
    let func = handler_fn(handler);
    lambda_runtime::run(func).await?;
    Ok(())
}

#[derive(Debug, Deserialize, PartialEq)]
struct MyEvent {
    item_name: String,
    price: f32,
}

async fn handler(event: Value, _context: Context) -> Result<Value, Error> {
    // Deserialize the incoming event into our MyEvent struct
    let my_event: MyEvent = serde_json::from_value(event)?;

    // Generate a unique ID for the item
    let item_id = Uuid::new_v4().to_string();

    let item = build_item(&item_id, &my_event);

    // Create a DynamoDB client
    let region_provider = RegionProviderChain::default_provider().or_else("eu-west-1");
    let config = aws_config::from_env().region(region_provider).load().await;
    // We borrow the config, so that we don't transfer ownership of it to the client. This allows us to use the config in other parts of our code if needed.
    let client = Client::new(&config);

    // Insert the item into the DynamoDB table
    client
        .put_item()
        .table_name(TABLE_NAME)
        .set_item(Some(item))
        .send()
        .await?;

    // Return a success response
    Ok(success_response(&item_id))
}

/// Builds the DynamoDB item (attribute map) for a new shop item.
/// Pure function: no I/O, easy to unit test.
fn build_item(item_id: &str, event: &MyEvent) -> HashMap<String, AttributeValue> {
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

/// Builds the success response body returned by the handler.
/// Pure function: no I/O, easy to unit test.
fn success_response(item_id: &str) -> Value {
    json!({"status": "success", "item_id": item_id})
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deserializes_valid_event() {
        let raw = json!({"item_name": "Widget", "price": 9.99});

        let event: MyEvent = serde_json::from_value(raw).unwrap();

        assert_eq!(
            event,
            MyEvent {
                item_name: "Widget".to_string(),
                price: 9.99,
            }
        );
    }

    #[test]
    fn rejects_event_missing_price() {
        let raw = json!({"item_name": "Widget"});

        let result: Result<MyEvent, _> = serde_json::from_value(raw);

        assert!(result.is_err());
    }

    #[test]
    fn rejects_event_with_wrong_type_for_price() {
        let raw = json!({"item_name": "Widget", "price": "not-a-number"});

        let result: Result<MyEvent, _> = serde_json::from_value(raw);

        assert!(result.is_err());
    }

    #[test]
    fn build_item_maps_all_fields_correctly() {
        let event = MyEvent {
            item_name: "Widget".to_string(),
            price: 9.99,
        };

        let item = build_item("test-id-123", &event);

        assert_eq!(
            item.get("item_id"),
            Some(&AttributeValue::S("test-id-123".to_string()))
        );
        assert_eq!(
            item.get("item_name"),
            Some(&AttributeValue::S("Widget".to_string()))
        );
        assert_eq!(
            item.get("price"),
            Some(&AttributeValue::N("9.99".to_string()))
        );
    }

    #[test]
    fn build_item_has_exactly_three_attributes() {
        let event = MyEvent {
            item_name: "Widget".to_string(),
            price: 1.0,
        };

        let item = build_item("some-id", &event);

        assert_eq!(item.len(), 3);
    }

    #[test]
    fn success_response_has_expected_shape() {
        let response = success_response("abc-123");

        assert_eq!(response, json!({"status": "success", "item_id": "abc-123"}));
    }
}
