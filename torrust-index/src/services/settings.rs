//! Settings service.
use std::fmt;
use std::str::FromStr;
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use url::Url;

use super::authorization::{self, ACTION};
use crate::config::{self, Configuration, Settings};
use crate::errors::ServiceError;
use crate::models::user::UserId;

pub struct Service {
    configuration: Arc<Configuration>,
    authorization_service: Arc<authorization::Service>,
}

impl Service {
    #[must_use]
    pub fn new(configuration: Arc<Configuration>, authorization_service: Arc<authorization::Service>) -> Service {
        Service {
            configuration,
            authorization_service,
        }
    }

    /// It gets all the settings.
    ///
    /// # Errors
    ///
    /// It returns an error if the user does not have the required permissions.
    pub async fn get_all(&self, maybe_user_id: Option<UserId>) -> Result<Settings, ServiceError> {
        self.authorization_service
            .authorize(ACTION::GetSettings, maybe_user_id)
            .await?;

        let torrust_index_configuration = self.configuration.get_all().await;

        Ok(torrust_index_configuration)
    }

    /// It gets all the settings making the secrets with asterisks.
    ///
    /// # Errors
    ///
    /// It returns an error if the user does not have the required permissions.
    pub async fn get_all_masking_secrets(&self, maybe_user_id: Option<UserId>) -> Result<Settings, ServiceError> {
        self.authorization_service
            .authorize(ACTION::GetSettingsSecret, maybe_user_id)
            .await?;

        let mut torrust_index_configuration = self.configuration.get_all().await;

        torrust_index_configuration.remove_secrets();

        Ok(torrust_index_configuration)
    }

    /// It gets only the public settings.
    ///
    /// # Errors
    ///
    /// It returns an error if the user does not have the required permissions.
    pub async fn get_public(&self, maybe_user_id: Option<UserId>) -> Result<ConfigurationPublic, ServiceError> {
        self.authorization_service
            .authorize(ACTION::GetPublicSettings, maybe_user_id)
            .await?;

        let settings_lock = self.configuration.get_all().await;
        Ok(extract_public_settings(&settings_lock))
    }

    /// It gets the site name from the settings.
    ///
    /// # Errors
    ///
    /// It returns an error if the user does not have the required permissions.
    pub async fn get_site_name(&self, maybe_user_id: Option<UserId>) -> Result<String, ServiceError> {
        self.authorization_service
            .authorize(ACTION::GetSiteName, maybe_user_id)
            .await?;

        Ok(self.configuration.get_site_name().await)
    }
}

fn extract_public_settings(settings: &Settings) -> ConfigurationPublic {
    let email_on_signup = match &settings.registration {
        Some(registration) => match &registration.email {
            Some(email) => {
                if email.required {
                    EmailOnSignup::Required
                } else {
                    EmailOnSignup::Optional
                }
            }
            None => EmailOnSignup::NotIncluded,
        },
        None => EmailOnSignup::NotIncluded,
    };

    ConfigurationPublic {
        website_name: settings.website.name.clone(),
        tracker_url: settings.tracker.url.clone(),
        tracker_listed: settings.tracker.listed,
        tracker_private: settings.tracker.private,
        email_on_signup,
        website: settings.website.clone().into(),
    }
}

/// The public index configuration.
/// There is an endpoint to get this configuration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ConfigurationPublic {
    website_name: String,
    tracker_url: Url,
    tracker_listed: bool,
    tracker_private: bool,
    email_on_signup: EmailOnSignup,
    website: Website,
}

/// Whether the email is required on signup or not.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum EmailOnSignup {
    /// The email is required on signup.
    Required,
    /// The email is optional on signup.
    Optional,
    /// The email is not allowed on signup. It will only be ignored if provided.
    NotIncluded,
}

impl Default for EmailOnSignup {
    fn default() -> Self {
        Self::Optional
    }
}

impl fmt::Display for EmailOnSignup {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let display_str = match self {
            EmailOnSignup::Required => "required",
            EmailOnSignup::Optional => "optional",
            EmailOnSignup::NotIncluded => "ignored",
        };
        write!(f, "{display_str}")
    }
}

impl FromStr for EmailOnSignup {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "required" => Ok(EmailOnSignup::Required),
            "optional" => Ok(EmailOnSignup::Optional),
            "none" => Ok(EmailOnSignup::NotIncluded),
            _ => Err(format!(
                "Unknown config 'email_on_signup' option (required, optional, none): {s}"
            )),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Website {
    pub name: String,
    pub demo: Option<Demo>,
    pub terms: Terms,
}

impl From<config::Website> for Website {
    fn from(website: config::Website) -> Self {
        Self {
            name: website.name,
            demo: website.demo.map(std::convert::Into::into),
            terms: website.terms.into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Demo {
    pub warning: String,
}

impl From<config::Demo> for Demo {
    fn from(demo: config::Demo) -> Self {
        Self { warning: demo.warning }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Terms {
    pub page: TermsPage,
    pub upload: TermsUpload,
}

impl From<config::Terms> for Terms {
    fn from(terms: config::Terms) -> Self {
        Self {
            page: terms.page.into(),
            upload: terms.upload.into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TermsPage {
    pub title: String,
    pub content: Markdown,
}

impl From<config::TermsPage> for TermsPage {
    fn from(terms_page: config::TermsPage) -> Self {
        Self {
            title: terms_page.title,
            content: terms_page.content.into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TermsUpload {
    pub content_upload_agreement: Markdown,
}

impl From<config::TermsUpload> for TermsUpload {
    fn from(terms_upload: config::TermsUpload) -> Self {
        Self {
            content_upload_agreement: terms_upload.content_upload_agreement.into(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Markdown(pub String);

impl Markdown {
    fn new(content: &str) -> Self {
        Self(content.to_owned())
    }
}

impl From<config::Markdown> for Markdown {
    fn from(markdown: config::Markdown) -> Self {
        Self::new(&markdown.source())
    }
}

#[cfg(test)]
mod tests {
    use crate::config::Configuration;
    use crate::services::settings::{extract_public_settings, ConfigurationPublic, EmailOnSignup};

    #[tokio::test]
    async fn configuration_should_return_only_public_settings() {
        let configuration = Configuration::default();
        let all_settings = configuration.get_all().await;

        let email_on_signup = match &all_settings.registration {
            Some(registration) => match &registration.email {
                Some(email) => {
                    if email.required {
                        EmailOnSignup::Required
                    } else {
                        EmailOnSignup::Optional
                    }
                }
                None => EmailOnSignup::NotIncluded,
            },
            None => EmailOnSignup::NotIncluded,
        };

        assert_eq!(
            extract_public_settings(&all_settings),
            ConfigurationPublic {
                website_name: all_settings.website.name.clone(),
                tracker_url: all_settings.tracker.url,
                tracker_listed: all_settings.tracker.listed,
                tracker_private: all_settings.tracker.private,
                email_on_signup,
                website: all_settings.website.into(),
            }
        );
    }
}
