//! The tracker REST API with all its versions.
//!
//! > **NOTICE**: This API should not be exposed directly to the internet, it is
//! > intended for internal use only.
//!
//! Endpoints for the latest API: [v1].
//!
//! All endpoints require an authorization token which must be set in the
//! configuration before running the tracker. The default configuration uses
//! `?token=MyAccessToken`. Refer to [Authentication](#authentication) for more
//! information.
//!
//! # Table of contents
//!
//! - [Configuration](#configuration)
//! - [Authentication](#authentication)
//! - [Versioning](#versioning)
//! - [Endpoints](#endpoints)
//! - [Documentation](#documentation)
//!
//! # Configuration
//!
//! The configuration file has a [`[http_api]`](torrust_tracker_configuration::HttpApi)
//! section that can be used to enable the API.
//!
//! ```toml
//! [http_api]
//! bind_address = "0.0.0.0:1212"
//!
//! [http_api.tsl_config]
//! ssl_cert_path = "./storage/tracker/lib/tls/localhost.crt"
//! ssl_key_path = "./storage/tracker/lib/tls/localhost.key"
//!
//! [http_api.access_tokens]
//! admin = "MyAccessToken"
//! ```
//!
//! Refer to [`torrust-tracker-configuration`](torrust_tracker_configuration)
//! for more information about the API configuration.
//!
//! When you run the tracker with enabled API, you will see the following message:
//!
//! ```text
//! Loading configuration from config file ./tracker.toml
//! 023-03-28T12:19:24.963054069+01:00 [torrust_tracker::bootstrap::logging][INFO] Logging initialized
//! ...
//! 023-03-28T12:19:24.964138723+01:00 [torrust_tracker::bootstrap::jobs::tracker_apis][INFO] Starting Torrust APIs server on: http://0.0.0.0:1212
//! ```
//!
//! The API server will be available on the address specified in the configuration.
//!
//! You can test the API by loading the following URL on a browser:
//!
//! <http://0.0.0.0:1212/api/v1/stats?token=MyAccessToken>
//!
//! Or using `curl`:
//!
//! ```bash
//! $ curl -s "http://0.0.0.0:1212/api/v1/stats?token=MyAccessToken"
//! ```
//!
//! The response will be a JSON object. For example, the [tracker statistics
//! endpoint](crate::v1::context::stats#get-tracker-statistics):
//!
//! ```json
//! {
//!   "torrents": 0,
//!   "seeders": 0,
//!   "completed": 0,
//!   "leechers": 0,
//!   "tcp4_connections_handled": 0,
//!   "tcp4_announces_handled": 0,
//!   "tcp4_scrapes_handled": 0,
//!   "tcp6_connections_handled": 0,
//!   "tcp6_announces_handled": 0,
//!   "tcp6_scrapes_handled": 0,
//!   "udp4_connections_handled": 0,
//!   "udp4_announces_handled": 0,
//!   "udp4_scrapes_handled": 0,
//!   "udp6_connections_handled": 0,
//!   "udp6_announces_handled": 0,
//!   "udp6_scrapes_handled": 0
//! }
//! ```
//!
//! # Authentication
//!
//! The API supports authentication using a GET parameter token.
//!
//! <http://0.0.0.0:1212/api/v1/stats?token=MyAccessToken>
//!
//! You can set as many tokens as you want in the configuration file:
//!
//! ```toml
//! [http_api.access_tokens]
//! admin = "MyAccessToken"
//! ```
//!
//! The token label is used to identify the token. All tokens have full access
//! to the API.
//!
//! Refer to [`torrust-tracker-configuration`](torrust_tracker_configuration)
//! for more information about the API configuration and to the
//! [`auth`](crate::v1::middlewares::auth) middleware for more
//! information about the authentication process.
//!
//! # Setup SSL (optional)
//!
//! The API server supports SSL. You can enable it by adding the `tsl_config`
//! section to the configuration.
//!
//! ```toml
//! [http_api]
//! bind_address = "0.0.0.0:1212"
//!
//! [http_api.tsl_config]
//! ssl_cert_path = "./storage/tracker/lib/tls/localhost.crt"
//! ssl_key_path = "./storage/tracker/lib/tls/localhost.key"
//!
//! [http_api.access_tokens]
//! admin = "MyAccessToken"
//! ```
//!
//! > **NOTICE**: If you are using a reverse proxy like NGINX, you can skip this
//! > step and use NGINX for the SSL instead. See
//! > [other alternatives to Nginx/certbot](https://github.com/torrust/torrust-tracker/discussions/131)
//!
//! > **NOTICE**: You can generate a self-signed certificate for localhost using
//! > OpenSSL. See [Let's Encrypt](https://letsencrypt.org/docs/certificates-for-localhost/).
//! > That's particularly useful for testing purposes. Once you have the certificate
//! > you need to set the [`ssl_cert_path`](torrust_tracker_configuration::HttpApi::tsl_config.ssl_cert_path)
//! > and [`ssl_key_path`](torrust_tracker_configuration::HttpApi::tsl_config.ssl_key_path)
//! > options in the configuration file with the paths to the certificate
//! > (`localhost.crt`) and key (`localhost.key`) files.
//!
//! # Versioning
//!
//! The API is versioned and each version has its own module.
//! The API server runs all the API versions on the same server using
//! the same port. Currently there is only one API version: [v1]
//! but a version [`v2`](https://github.com/torrust/torrust-tracker/issues/144)
//! is planned.
//!
//! # Endpoints
//!
//! Refer to the [v1] module for the list of available
//! API endpoints.
//!
//! # Documentation
//!
//! If you want to contribute to this documentation you can [open a new pull request](https://github.com/torrust/torrust-tracker/pulls).
//!
//! > **NOTICE**: we are using [curl](https://curl.se/) in the API examples.
//! > And you have to use quotes around the URL in order to avoid unexpected
//! > errors. For example: `curl "http://127.0.0.1:1212/api/v1/stats?token=MyAccessToken"`.
pub mod environment;
pub mod routes;
pub mod server;
pub mod v1;

use serde::{Deserialize, Serialize};
use torrust_tracker_clock::clock;

/// This code needs to be copied into each crate.
/// Working version, for production.
#[cfg(not(test))]
#[allow(dead_code)]
pub(crate) type CurrentClock = clock::Working;

/// Stopped version, for testing.
#[cfg(test)]
#[allow(dead_code)]
pub(crate) type CurrentClock = clock::Stopped;

pub const API_LOG_TARGET: &str = "API";

/// The info hash URL path parameter.
///
/// Some API endpoints require an info hash as a path parameter.
///
/// For example: `http://localhost:1212/api/v1/torrent/{info_hash}`.
///
/// The info hash represents teh value collected from the URL path parameter.
/// It does not include validation as this is done by the API endpoint handler,
/// in order to provide a more specific error message.
#[derive(Deserialize)]
pub struct InfoHashParam(pub String);

/// The version of the HTTP Api.
#[derive(Serialize, Deserialize, Copy, Clone, PartialEq, Eq, Debug)]
pub enum Version {
    /// The `v1` version of the HTTP Api.
    V1,
}
