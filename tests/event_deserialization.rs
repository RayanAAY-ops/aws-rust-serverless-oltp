use aws_rust_serverless_oltp::MyEvent;
use serde_json::json;

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
