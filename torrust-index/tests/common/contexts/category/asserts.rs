use crate::common::asserts::assert_json_ok_response;
use crate::common::contexts::category::responses::{AddedCategoryResponse, DeletedCategoryResponse};
use crate::common::responses::TextResponse;

pub fn assert_added_category_response(response: &TextResponse, category_name: &str) {
    let added_category_response: AddedCategoryResponse = serde_json::from_str(&response.body)
        .unwrap_or_else(|_| panic!("response {:#?} should be a AddedCategoryResponse", response.body));

    assert_eq!(added_category_response.data, category_name);

    assert_json_ok_response(response);
}

pub fn assert_deleted_category_response(response: &TextResponse, category_name: &str) {
    let deleted_category_response: DeletedCategoryResponse = serde_json::from_str(&response.body)
        .unwrap_or_else(|_| panic!("response {:#?} should be a DeletedCategoryResponse", response.body));

    assert_eq!(deleted_category_response.data, category_name);

    assert_json_ok_response(response);
}
