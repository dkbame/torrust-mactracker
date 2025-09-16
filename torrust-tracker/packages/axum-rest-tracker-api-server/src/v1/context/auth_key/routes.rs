//! API routes for the [`auth_key`](crate::v1::context::auth_key)
//! API context.
//!
//! - `POST /key/:seconds_valid`
//! - `DELETE /key/:key`
//! - `GET /keys/reload`
//!
//! Refer to the [API endpoint documentation](crate::v1::context::auth_key).
use std::sync::Arc;

use axum::routing::{get, post};
use axum::Router;
use bittorrent_tracker_core::authentication::handler::KeysHandler;

use super::handlers::{add_auth_key_handler, delete_auth_key_handler, generate_auth_key_handler, reload_keys_handler};

/// It adds the routes to the router for the [`auth_key`](crate::v1::context::auth_key) API context.
pub fn add(prefix: &str, router: Router, keys_handler: &Arc<KeysHandler>) -> Router {
    // Keys
    router
        .route(
            // code-review: Axum does not allow two routes with the same path but different path variable name.
            // In the new major API version, `seconds_valid` should be a POST form field so that we will have two paths:
            //
            // POST /keys
            // DELETE /keys/:key
            //
            // The POST /key/:seconds_valid has been deprecated and it will removed in the future.
            // Use POST /keys
            &format!("{prefix}/key/{{seconds_valid_or_key}}"),
            post(generate_auth_key_handler)
                .with_state(keys_handler.clone())
                .delete(delete_auth_key_handler)
                .with_state(keys_handler.clone()),
        )
        // Keys command
        .route(
            &format!("{prefix}/keys/reload"),
            get(reload_keys_handler).with_state(keys_handler.clone()),
        )
        .route(
            &format!("{prefix}/keys"),
            post(add_auth_key_handler).with_state(keys_handler.clone()),
        )
}
