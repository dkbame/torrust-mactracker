#![allow(clippy::missing_errors_doc)]

use std::fs;

use sqlx::sqlite::SqlitePoolOptions;
use sqlx::{query, SqlitePool};
use torrust_index::upgrades::from_v1_0_0_to_v2_0_0::databases::sqlite_v1_0_0::{
    CategoryRecordV1, TorrentRecordV1, TrackerKeyRecordV1, UserRecordV1,
};

pub struct SqliteDatabaseV1_0_0 {
    pub pool: SqlitePool,
}

impl SqliteDatabaseV1_0_0 {
    pub async fn db_connection(database_file: &str) -> Self {
        let connect_url = format!("sqlite://{database_file}?mode=rwc");
        Self::new(&connect_url).await
    }

    pub async fn new(database_url: &str) -> Self {
        let db = SqlitePoolOptions::new()
            .connect(database_url)
            .await
            .expect("Unable to create database pool.");
        Self { pool: db }
    }

    /// Execute migrations for database in version v1.0.0
    pub async fn migrate(&self, fixtures_dir: &str) {
        let migrations_dir = format!("{fixtures_dir}database/v1.0.0/migrations/");

        let migrations = vec![
            "20210831113004_torrust_users.sql",
            "20210904135524_torrust_tracker_keys.sql",
            "20210905160623_torrust_categories.sql",
            "20210907083424_torrust_torrent_files.sql",
            "20211208143338_torrust_users.sql",
            "20220308083424_torrust_torrents.sql",
            "20220308170028_torrust_categories.sql",
        ];

        for migration_file_name in &migrations {
            let migration_file_path = format!("{}{}", &migrations_dir, &migration_file_name);
            self.run_migration_from_file(&migration_file_path).await;
        }
    }

    async fn run_migration_from_file(&self, migration_file_path: &str) {
        println!("Executing migration: {migration_file_path:?}");

        let sql = fs::read_to_string(migration_file_path).expect("Should have been able to read the file");

        let res = sqlx::query(&sql).execute(&self.pool).await;

        println!("Migration result {res:?}");
    }

    pub async fn insert_category(&self, category: &CategoryRecordV1) -> Result<i64, sqlx::Error> {
        query("INSERT INTO torrust_categories (category_id, name) VALUES (?, ?)")
            .bind(category.category_id)
            .bind(category.name.clone())
            .execute(&self.pool)
            .await
            .map(|v| v.last_insert_rowid())
    }

    #[allow(clippy::missing_panics_doc)]
    pub async fn delete_all_categories(&self) -> Result<(), sqlx::Error> {
        query("DELETE FROM torrust_categories").execute(&self.pool).await.unwrap();
        Ok(())
    }

    pub async fn insert_user(&self, user: &UserRecordV1) -> Result<i64, sqlx::Error> {
        query("INSERT INTO torrust_users (user_id, username, email, email_verified, password, administrator) VALUES (?, ?, ?, ?, ?, ?)")
            .bind(user.user_id)
            .bind(user.username.clone())
            .bind(user.email.clone())
            .bind(user.email_verified)
            .bind(user.password.clone())
            .bind(user.administrator)
            .execute(&self.pool)
            .await
            .map(|v| v.last_insert_rowid())
    }

    pub async fn insert_tracker_key(&self, tracker_key: &TrackerKeyRecordV1) -> Result<i64, sqlx::Error> {
        query("INSERT INTO torrust_tracker_keys (key_id, user_id, key, valid_until) VALUES (?, ?, ?, ?)")
            .bind(tracker_key.key_id)
            .bind(tracker_key.user_id)
            .bind(tracker_key.key.clone())
            .bind(tracker_key.valid_until)
            .execute(&self.pool)
            .await
            .map(|v| v.last_insert_rowid())
    }

    pub async fn insert_torrent(&self, torrent: &TorrentRecordV1) -> Result<i64, sqlx::Error> {
        query(
            "INSERT INTO torrust_torrents (
            torrent_id,
            uploader,
            info_hash,
            title,
            category_id,
            description,
            upload_date,
            file_size,
            seeders,
            leechers
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(torrent.torrent_id)
        .bind(torrent.uploader.clone())
        .bind(torrent.info_hash.clone())
        .bind(torrent.title.clone())
        .bind(torrent.category_id)
        .bind(torrent.description.clone())
        .bind(torrent.upload_date)
        .bind(torrent.file_size)
        .bind(torrent.seeders)
        .bind(torrent.leechers)
        .execute(&self.pool)
        .await
        .map(|v| v.last_insert_rowid())
    }
}
