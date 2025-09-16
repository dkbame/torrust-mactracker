//! A console command to upgrade the application from version `v1.0.0` to `v2.0.0`.
//!
//! # Usage
//!
//! ```bash
//! cargo run --bin upgrade SOURCE_DB_FILE TARGET_DB_FILE TORRENT_UPLOAD_DIR
//! ```
//!
//! Where:
//!
//! - `SOURCE_DB_FILE` is the source database in version `v1.0.0` we want to migrate.
//! - `TARGET_DB_FILE` is the new migrated database in version `v2.0.0`.
//! - `TORRENT_UPLOAD_DIR` is the relative dir where torrent files are stored.
//!
//! For example:
//!
//! ```bash
//! cargo run --bin upgrade ./data.db ./data_v2.db ./uploads
//! ```
//!
//! This command was created to help users to migrate from version `v1.0.0` to
//! `v2.0.0`. The main changes in version `v2.0.0` were:
//!
//! - The database schema was changed.
//! - The torrents are now stored entirely in the database. The torrent files
//!   are not stored in the filesystem anymore. This command reads the torrent
//!   files from the filesystem and store them in the database.
//!
//! We recommend to download your production database and the torrent files dir.
//! And run the command in a local environment with the version `v2.0.0.`. Then,
//! you can run the app locally and make sure all the data was migrated
//! correctly.
//!
//! # Notes
//!
//! NOTES for `torrust_users` table transfer:
//!
//! - In v2, the table `torrust_user` contains a field `date_registered` non
//!   existing in v1. We changed that column to allow `NULL`. We also added the
//!   new column `date_imported` with the datetime when the upgrader was executed.
//!
//! NOTES for `torrust_user_profiles` table transfer:
//!
//! - In v2, the table `torrust_user_profiles` contains two new fields: `bio`
//!   and `avatar`. Empty string is used as default value.
//!
//!
//! If you want more information about this command you can read the [issue 56](https://github.com/torrust/torrust-index/issues/56).
use std::env;
use std::time::SystemTime;

use chrono::prelude::{DateTime, Utc};
use text_colorizer::Colorize;

use crate::upgrades::from_v1_0_0_to_v2_0_0::databases::{current_db, migrate_target_database, new_db, truncate_target_database};
use crate::upgrades::from_v1_0_0_to_v2_0_0::transferrers::category_transferrer::transfer_categories;
use crate::upgrades::from_v1_0_0_to_v2_0_0::transferrers::torrent_transferrer::transfer_torrents;
use crate::upgrades::from_v1_0_0_to_v2_0_0::transferrers::tracker_key_transferrer::transfer_tracker_keys;
use crate::upgrades::from_v1_0_0_to_v2_0_0::transferrers::user_transferrer::transfer_users;

const NUMBER_OF_ARGUMENTS: usize = 3;

#[derive(Debug)]
pub struct Arguments {
    /// The source database in version v1.0.0 we want to migrate
    pub source_database_file: String,
    /// The new migrated database in version v2.0.0
    pub target_database_file: String,
    // The relative dir where torrent files are stored
    pub upload_path: String,
}

fn print_usage() {
    eprintln!(
        "{} - migrates date from version v1.0.0 to v2.0.0.

        cargo run --bin upgrade SOURCE_DB_FILE TARGET_DB_FILE TORRENT_UPLOAD_DIR

        For example:

        cargo run --bin upgrade ./data.db ./data_v2.db ./uploads

        ",
        "Upgrader".green()
    );
}

fn parse_args() -> Arguments {
    let args: Vec<String> = env::args().skip(1).collect();

    if args.len() != NUMBER_OF_ARGUMENTS {
        eprintln!(
            "{} wrong number of arguments: expected {}, got {}",
            "Error".red().bold(),
            NUMBER_OF_ARGUMENTS,
            args.len()
        );
        print_usage();
    }

    Arguments {
        source_database_file: args[0].clone(),
        target_database_file: args[1].clone(),
        upload_path: args[2].clone(),
    }
}

pub async fn run() {
    let now = datetime_iso_8601();
    upgrade(&parse_args(), &now).await;
}

pub async fn upgrade(args: &Arguments, date_imported: &str) {
    // Get connection to the source database (current DB in settings)
    let source_database = current_db(&args.source_database_file).await;

    // Get connection to the target database (new DB we want to migrate the data)
    let target_database = new_db(&args.target_database_file).await;

    println!("Upgrading data from version v1.0.0 to v2.0.0 ...");

    migrate_target_database(target_database.clone()).await;
    truncate_target_database(target_database.clone()).await;

    transfer_categories(source_database.clone(), target_database.clone()).await;
    transfer_users(source_database.clone(), target_database.clone(), date_imported).await;
    transfer_tracker_keys(source_database.clone(), target_database.clone()).await;
    transfer_torrents(source_database.clone(), target_database.clone(), &args.upload_path).await;

    println!("Upgrade data from version v1.0.0 to v2.0.0 finished!\n");

    eprintln!(
        "{}\nWe recommend you to run the command to import torrent statistics for all torrents manually. \
         If you do not do it the statistics will be imported anyway during the normal execution of the program. \
         You can import statistics manually with:\n {}",
        "SUGGESTION: \n".yellow(),
        "cargo run --bin import_tracker_statistics".yellow()
    );
}

/// Current datetime in ISO8601 without time zone.
/// For example: `2022-11-10 10:35:15`
#[must_use]
pub fn datetime_iso_8601() -> String {
    let dt: DateTime<Utc> = SystemTime::now().into();
    format!("{}", dt.format("%Y-%m-%d %H:%M:%S"))
}
