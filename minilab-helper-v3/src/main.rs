mod config;
mod dictionaries;
mod docker;

use std::sync::Arc;

use serenity::all::*;
use tracing::{error, info};

use config::Config;
use dictionaries::docker_services::{ServiceName, group_by_category, monitored_services};
use docker::{ContainerStatus, DockerClient, HealthStatus, get_rpi_temperature};

struct Handler {
    docker: Arc<DockerClient>,
    owner_id: UserId,
}

#[serenity::async_trait]
impl EventHandler for Handler {
    async fn ready(&self, ctx: Context, ready: Ready) {
        info!("Connecté en tant que {}", ready.user.name);

        let commands = vec![
            CreateCommand::new("status").description("Statut des services du minilab"),
            CreateCommand::new("resources").description("Ressources CPU / RAM des services"),
        ];

        match Command::set_global_commands(&ctx.http, commands).await {
            Ok(_) => info!("Commandes slash enregistrées globalement."),
            Err(err) => error!("Erreur enregistrement des commandes: {err:?}"),
        }
    }

    async fn interaction_create(&self, ctx: Context, interaction: Interaction) {
        let Interaction::Command(command) = interaction else {
            return;
        };

        if command.user.id != self.owner_id {
            let reply = CreateInteractionResponseMessage::new()
                .content("🚫 Tu n'es pas autorisé à utiliser cette commande.")
                .ephemeral(true);
            let _ = command
                .create_response(&ctx.http, CreateInteractionResponse::Message(reply))
                .await;
            return;
        }

        if let Err(err) = command.defer_ephemeral(&ctx.http).await {
            error!("Erreur defer: {err:?}");
            return;
        }

        let embed = match command.data.name.as_str() {
            "status" => build_status_embed(&self.docker).await,
            "resources" => build_resources_embed(&self.docker).await,
            _ => return,
        };

        let reply = EditInteractionResponse::new().embed(embed);
        if let Err(err) = command.edit_response(&ctx.http, reply).await {
            error!("Erreur envoi de la réponse: {err:?}");
        }
    }
}

// ── /status ──────────────────────────────────────────────────────────────

async fn build_status_embed(docker: &DockerClient) -> CreateEmbed {
    let base = CreateEmbed::new()
        .title("📊 Statut du minilab")
        .colour(0x5865F2u32);
    let services = monitored_services();

    match docker.get_all_statuses().await {
        Ok(statuses) => add_grouped_service_fields(base, &services, |service| {
            statuses
                .iter()
                .find(|status| status.name == service)
                .map(|status| {
                    format!(
                        "{}  •  🔁 {}",
                        render_container_state_line(status),
                        status.restart_count
                    )
                })
        }),
        Err(err) => base.description(format!("❌ Erreur Docker : {err}")),
    }
}

fn render_container_state_line(status: &ContainerStatus) -> String {
    let is_running = status.state == "running";
    let has_health = status.health != HealthStatus::NoHealthcheck;

    if has_health && is_running {
        format!("{} `{}`", status.health.emoji(), status.health.as_str())
    } else {
        let dot = if is_running { "🟢" } else { "🔴" };
        format!("{dot} `{}`", status.state)
    }
}

// ── /resources ───────────────────────────────────────────────────────────

async fn build_resources_embed(docker: &DockerClient) -> CreateEmbed {
    let services = monitored_services();

    let description = match get_rpi_temperature().await {
        Some(temp) => format!("🌡️ Température RPi : {} **{temp}°C**", temp_emoji(temp)),
        None => "🌡️ Température RPi : ❌ indisponible".to_string(),
    };

    let base = CreateEmbed::new()
        .title("📈 Ressources CPU / RAM — minilab")
        .description(description)
        .colour(0x57F287u32);

    let mut usages = Vec::with_capacity(services.len());
    for &service in &services {
        usages.push((service, docker.get_resource_usage(service).await));
    }

    add_grouped_service_fields(base, &services, |service| {
        match usages.iter().find(|(s, _)| *s == service) {
            Some((_, Ok(usage))) => Some(format!(
                "CPU : `{:.1}%`\nRAM : `{}MB ({:.1}%)`",
                usage.cpu_percent, usage.mem_usage_mb, usage.mem_percent
            )),
            _ => Some("❌ Stats indisponibles\n(conteneur arrêté ?)".to_string()),
        }
    })
}

fn temp_emoji(celsius: i64) -> &'static str {
    if celsius >= 70 {
        "🔴"
    } else if celsius >= 60 {
        "🟡"
    } else {
        "🟢"
    }
}

// ── Rendu partagé ────────────────────────────────────────────────────────

fn add_grouped_service_fields(
    embed: CreateEmbed,
    services: &[ServiceName],
    mut build_value: impl FnMut(ServiceName) -> Option<String>,
) -> CreateEmbed {
    group_by_category(services).into_iter().fold(
        embed,
        |embed, (category, services_in_category)| {
            let embed = embed.field("\u{200B}", format!("**{}**", category.label()), false);
            services_in_category
                .into_iter()
                .fold(embed, |embed, service| match build_value(service) {
                    None => embed,
                    Some(value) => {
                        let def = service.definition();
                        embed.field(format!("{} {}", def.emoji, def.label), value, true)
                    }
                })
        },
    )
}

// ── Entrée ───────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let config = Config::from_env()?;
    let docker = Arc::new(DockerClient::new()?);

    let handler = Handler {
        docker,
        owner_id: UserId::new(config.discord_owner_id),
    };

    let mut client = Client::builder(&config.discord_token, GatewayIntents::empty())
        .application_id(ApplicationId::new(config.discord_client_id))
        .event_handler(handler)
        .await?;

    client.start().await?;
    Ok(())
}
