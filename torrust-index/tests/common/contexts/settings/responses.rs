use serde::Deserialize;
use url::Url;

use super::Settings;

#[derive(Deserialize)]
pub struct AllSettingsResponse {
    pub data: Settings,
}

#[derive(Deserialize)]
pub struct PublicSettingsResponse {
    pub data: Public,
}

#[derive(Deserialize, PartialEq, Debug)]
pub struct Public {
    pub website_name: String,
    pub tracker_url: Url,
    pub tracker_listed: bool,
    pub tracker_private: bool,
    pub email_on_signup: String,
}

#[derive(Deserialize)]
pub struct SiteNameResponse {
    pub data: String,
}
