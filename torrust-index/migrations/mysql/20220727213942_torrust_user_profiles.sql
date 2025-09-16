CREATE TABLE IF NOT EXISTS torrust_user_profiles (
    user_id INTEGER NOT NULL PRIMARY KEY,
    username VARCHAR(24) NOT NULL UNIQUE,
    email VARCHAR(320) UNIQUE,
    email_verified BOOL NOT NULL DEFAULT FALSE,
    bio TEXT,
    avatar TEXT,
    FOREIGN KEY(user_id) REFERENCES torrust_users(user_id) ON DELETE CASCADE
)
