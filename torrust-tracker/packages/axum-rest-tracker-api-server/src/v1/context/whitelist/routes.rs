//! API routes for the [`whitelist`](crate::v1::context::whitelist) API context.
//!
//! - `POST /whitelist/:info_hash`
//! - `DELETE /whitelist/:info_hash`
//! - `GET /whitelist/reload`
//!
//! Refer to the [API endpoint documentation](crate::v1::context::torrent).
use std::sync::Arc;

use axum::routing::{delete, get, post};
use axum::Router;
use bittorrent_tracker_core::whitelist::manager::WhitelistManager;

use super::handlers::{add_torrent_to_whitelist_handler, reload_whitelist_handler, remove_torrent_from_whitelist_handler};

/// It adds the routes to the router for the [`whitelist`](crate::v1::context::whitelist) API context.
pub fn add(prefix: &str, router: Router, whitelist_manager: &Arc<WhitelistManager>) -> Router {
    let prefix = format!("{prefix}/whitelist");

    router
        // Whitelisted torrents
        .route(
            &format!("{prefix}/{{info_hash}}"),
            post(add_torrent_to_whitelist_handler).with_state(whitelist_manager.clone()),
        )
        .route(
            &format!("{prefix}/{{info_hash}}"),
            delete(remove_torrent_from_whitelist_handler).with_state(whitelist_manager.clone()),
        )
        // Whitelist commands
        .route(
            &format!("{prefix}/reload"),
            get(reload_whitelist_handler).with_state(whitelist_manager.clone()),
        )
}
