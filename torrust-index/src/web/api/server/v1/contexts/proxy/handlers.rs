//! API handlers for the the [`proxy`](crate::web::api::server::v1::contexts::proxy) API
//! context.
use std::sync::Arc;

use axum::extract::{Path, State};
use axum::response::Response;

use super::responses::png_image;
use crate::common::AppData;
use crate::ui::proxy::map_error_to_image;
use crate::web::api::server::v1::extractors::optional_user_id::ExtractOptionalLoggedInUser;

/// Get the remote image. It uses the cached image if available.
#[allow(clippy::unused_async)]
pub async fn get_proxy_image_handler(
    State(app_data): State<Arc<AppData>>,
    ExtractOptionalLoggedInUser(maybe_user_id): ExtractOptionalLoggedInUser,
    Path(url): Path<String>,
) -> Response {
    // code-review: Handling status codes in the index-gui other tan OK is quite a pain.
    // Return OK for now.

    // todo: it also work for other image types but we are always returning the
    // same content type: `image/png`. If we only support PNG images we should
    // change the documentation and return an error for other image types.

    // Get image URL from URL path parameter.
    let image_url = urlencoding::decode(&url).unwrap_or_default().into_owned();

    match app_data.proxy_service.get_image_by_url(&image_url, maybe_user_id).await {
        Ok(image_bytes) => {
            // Returns the cached image.
            png_image(image_bytes)
        }
        Err(e) => {
            // Returns an error image.
            png_image(map_error_to_image(&e))
        }
    }
}
