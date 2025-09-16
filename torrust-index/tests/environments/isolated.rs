use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use tempfile::TempDir;
use torrust_index::config;
use torrust_index::config::v2::registration::{Email, Registration};
use torrust_index::config::{Threshold, FREE_PORT};
use torrust_index::web::api::Version;
use url::Url;

use super::app_starter::AppStarter;
use crate::common::random;

/// Provides an isolated test environment for testing. The environment is
/// launched with a temporary directory and a default ephemeral configuration
/// before running the test.
pub struct TestEnv {
    pub app_starter: AppStarter,
    pub temp_dir: TempDir,
}

impl TestEnv {
    /// Provides a running app instance for integration tests.
    pub async fn running(api_version: Version) -> Self {
        let mut env = Self::default();
        env.start(api_version).await;
        env
    }

    /// Provides a test environment with a default configuration for testing
    /// application.
    ///
    /// # Panics
    ///
    /// Panics if the temporary directory cannot be created.
    #[must_use]
    pub fn with_test_configuration() -> Self {
        let temp_dir = TempDir::new().expect("failed to create a temporary directory");

        let configuration = ephemeral(&temp_dir);

        let app_starter = AppStarter::with_custom_configuration(configuration);

        Self { app_starter, temp_dir }
    }

    /// Starts the app.
    pub async fn start(&mut self, api_version: Version) {
        self.app_starter.start(api_version).await;
    }

    /// Provides the whole server configuration.
    #[must_use]
    pub fn server_configuration(&self) -> config::Settings {
        self.app_starter.server_configuration()
    }

    /// Provides the API server socket address.
    #[must_use]
    pub fn server_socket_addr(&self) -> Option<String> {
        self.app_starter.server_socket_addr().map(|addr| addr.to_string())
    }

    #[must_use]
    pub fn database_connect_url(&self) -> String {
        self.app_starter.database_connect_url()
    }
}

impl Default for TestEnv {
    fn default() -> Self {
        Self::with_test_configuration()
    }
}

/// Provides a configuration with ephemeral data for testing.
fn ephemeral(temp_dir: &TempDir) -> config::Settings {
    let mut configuration = config::Settings::default();

    configuration.logging.threshold = Threshold::Off; // Change to `debug` for tests debugging

    // Ephemeral API port
    configuration.net.bind_address = SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), FREE_PORT);

    // Ephemeral Importer API port
    configuration.tracker_statistics_importer.port = FREE_PORT;

    // Ephemeral SQLite database
    configuration.database.connect_url =
        Url::parse(&format!("sqlite://{}?mode=rwc", random_database_file_path_in(temp_dir))).unwrap();

    // Enable user registration
    configuration.registration = Some(Registration {
        email: Some(Email {
            required: false,
            verification_required: false,
        }),
    });

    configuration
}

fn random_database_file_path_in(temp_dir: &TempDir) -> String {
    let random_db_id = random::string(16);
    let db_file_name = format!("data_{random_db_id}.db");
    temp_dir.path().join(db_file_name).to_string_lossy().to_string()
}
