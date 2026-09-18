use aws_rust_serverless_oltp::{MyEvent, build_item};
use aws_sdk_dynamodb::types::AttributeValue;

#[test]
fn build_item_maps_fields_correctly() {
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
