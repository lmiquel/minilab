use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub discord_token: String,
    pub discord_client_id: u64,
    pub discord_owner_id: u64,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Config> {
        // Charge un .env local si présent (dev) ; en prod les variables viennent
        // déjà de l'environnement du conteneur, dotenvy ne fait alors rien.
        let _ = dotenvy::dotenv();
        Ok(envy::from_env::<Config>()?)
    }
}
