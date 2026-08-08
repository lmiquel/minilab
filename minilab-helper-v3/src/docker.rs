use bollard::Docker;
use bollard::container::LogOutput;
use bollard::exec::{CreateExecOptions, StartExecOptions, StartExecResults};
use bollard::query_parameters::{
    RestartContainerOptionsBuilder, StartContainerOptions, StatsOptionsBuilder,
    StopContainerOptionsBuilder,
};
use futures_util::StreamExt;
use thiserror::Error;

use crate::dictionaries::docker_services::{ServiceName, monitored_services};

#[derive(Debug, Error)]
pub enum DockerError {
    #[error("erreur Docker: {0}")]
    Http(#[from] bollard::errors::Error),
    #[error("réponse Docker inattendue: {0}")]
    Unexpected(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HealthStatus {
    Healthy,
    Unhealthy,
    Starting,
    NoHealthcheck,
}

impl HealthStatus {
    pub fn emoji(self) -> &'static str {
        match self {
            HealthStatus::Healthy => "💚",
            HealthStatus::Unhealthy => "❤️‍🩹",
            HealthStatus::Starting => "⏳",
            HealthStatus::NoHealthcheck => "⬜",
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            HealthStatus::Healthy => "healthy",
            HealthStatus::Unhealthy => "unhealthy",
            HealthStatus::Starting => "starting",
            HealthStatus::NoHealthcheck => "none",
        }
    }

    fn from_bollard(status: bollard::models::HealthStatusEnum) -> HealthStatus {
        use bollard::models::HealthStatusEnum::*;
        match status {
            HEALTHY => HealthStatus::Healthy,
            UNHEALTHY => HealthStatus::Unhealthy,
            STARTING => HealthStatus::Starting,
            NONE | EMPTY => HealthStatus::NoHealthcheck,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ContainerStatus {
    pub name: ServiceName,
    pub state: String,
    pub restart_count: i64,
    pub health: HealthStatus,
}

#[derive(Debug, Clone, Copy)]
pub struct ResourceUsage {
    pub cpu_percent: f64,
    pub mem_usage_mb: i64,
    pub mem_percent: f64,
}

pub struct DockerClient {
    inner: Docker,
}

impl DockerClient {
    /// Se connecte via `DOCKER_HOST` (ex: `tcp://docker-socket-proxy:2375`),
    /// ou le socket local par défaut si absent.
    pub fn new() -> Result<DockerClient, DockerError> {
        Ok(DockerClient {
            inner: Docker::connect_with_defaults()?,
        })
    }

    pub async fn get_all_statuses(&self) -> Result<Vec<ContainerStatus>, DockerError> {
        let mut statuses = Vec::new();
        for service in monitored_services() {
            statuses.push(self.get_container_status(service).await?);
        }
        Ok(statuses)
    }

    pub async fn get_container_status(
        &self,
        service: ServiceName,
    ) -> Result<ContainerStatus, DockerError> {
        let container_name = service.definition().container_name;
        let inspect = self.inner.inspect_container(container_name, None).await?;

        let state = inspect
            .state
            .ok_or_else(|| DockerError::Unexpected("pas de State dans la réponse".into()))?;

        let status = state
            .status
            .map(|s| s.to_string())
            .unwrap_or_else(|| "unknown".to_string());

        let health = state
            .health
            .and_then(|h| h.status)
            .map(HealthStatus::from_bollard)
            .unwrap_or(HealthStatus::NoHealthcheck);

        Ok(ContainerStatus {
            name: service,
            state: status,
            restart_count: inspect.restart_count.unwrap_or(0),
            health,
        })
    }

    pub async fn get_resource_usage(
        &self,
        service: ServiceName,
    ) -> Result<ResourceUsage, DockerError> {
        let container_name = service.definition().container_name;
        let options = StatsOptionsBuilder::default()
            .stream(false)
            .one_shot(true)
            .build();

        let stats = self
            .inner
            .stats(container_name, Some(options))
            .next()
            .await
            .ok_or_else(|| DockerError::Unexpected("flux de stats vide".into()))??;

        let cpu = stats
            .cpu_stats
            .ok_or_else(|| DockerError::Unexpected("pas de cpu_stats".into()))?;
        let precpu = stats
            .precpu_stats
            .ok_or_else(|| DockerError::Unexpected("pas de precpu_stats".into()))?;
        let memory = stats
            .memory_stats
            .ok_or_else(|| DockerError::Unexpected("pas de memory_stats".into()))?;

        let cpu_delta = cpu
            .cpu_usage
            .as_ref()
            .and_then(|u| u.total_usage)
            .unwrap_or(0) as f64
            - precpu
                .cpu_usage
                .as_ref()
                .and_then(|u| u.total_usage)
                .unwrap_or(0) as f64;
        let system_delta =
            cpu.system_cpu_usage.unwrap_or(0) as f64 - precpu.system_cpu_usage.unwrap_or(0) as f64;
        let online_cpus = cpu.online_cpus.filter(|&n| n > 0).unwrap_or(1) as f64;

        let cpu_percent = if system_delta > 0.0 {
            round1(cpu_delta / system_delta * online_cpus * 100.0)
        } else {
            0.0
        };

        let inactive_file = memory
            .stats
            .as_ref()
            .and_then(|s| s.get("inactive_file"))
            .copied()
            .unwrap_or(0);
        let mem_used = memory.usage.unwrap_or(0).saturating_sub(inactive_file);
        let mem_limit = memory.limit.filter(|&n| n > 0).unwrap_or(1);

        Ok(ResourceUsage {
            cpu_percent,
            mem_usage_mb: (mem_used / 1024 / 1024) as i64,
            mem_percent: round1(mem_used as f64 / mem_limit as f64 * 100.0),
        })
    }

    pub async fn start_service(&self, service: ServiceName) -> Result<(), DockerError> {
        self.inner
            .start_container(
                service.definition().container_name,
                None::<StartContainerOptions>,
            )
            .await?;
        Ok(())
    }

    pub async fn stop_service(&self, service: ServiceName) -> Result<(), DockerError> {
        let options = StopContainerOptionsBuilder::default().t(10).build();
        self.inner
            .stop_container(service.definition().container_name, Some(options))
            .await?;
        Ok(())
    }

    pub async fn restart_service(&self, service: ServiceName) -> Result<(), DockerError> {
        let options = RestartContainerOptionsBuilder::default().t(10).build();
        self.inner
            .restart_container(service.definition().container_name, Some(options))
            .await?;
        Ok(())
    }

    /// Exécute une commande dans le conteneur (ex: les commandes `wg show ...`
    /// de WireGuard, qui ne passent pas par le docker-socket-proxy HTTP normal).
    /// `bollard` démultiplexe déjà le flux stdout/stderr brut de Docker — pas
    /// besoin de reparser les frames à la main comme sur un client HTTP fait maison.
    pub async fn exec(&self, service: ServiceName, cmd: &str) -> Result<String, DockerError> {
        let container_name = service.definition().container_name;
        let config = CreateExecOptions {
            cmd: Some(cmd.split(' ').map(str::to_string).collect()),
            attach_stdout: Some(true),
            attach_stderr: Some(true),
            ..Default::default()
        };

        let exec = self.inner.create_exec(container_name, config).await?;

        match self
            .inner
            .start_exec(&exec.id, None::<StartExecOptions>)
            .await?
        {
            StartExecResults::Attached { mut output, .. } => {
                let mut out = String::new();
                while let Some(frame) = output.next().await {
                    if let LogOutput::StdOut { message } = frame? {
                        out.push_str(&String::from_utf8_lossy(&message));
                    }
                }
                Ok(out)
            }
            StartExecResults::Detached => Ok(String::new()),
        }
    }
}

fn round1(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

const THERMAL_ZONE_PATH: &str = "/sys/class/thermal/thermal_zone0/temp";

/// Lit la température du RPi en °C (le fichier contient des millidegrés).
pub async fn get_rpi_temperature() -> Option<i64> {
    let raw = tokio::fs::read_to_string(THERMAL_ZONE_PATH).await.ok()?;
    let millidegrees: i64 = raw.trim().parse().ok()?;
    Some((millidegrees as f64 / 1000.0).round() as i64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn health_emoji_matches_status() {
        assert_eq!(HealthStatus::Healthy.emoji(), "💚");
        assert_eq!(HealthStatus::NoHealthcheck.emoji(), "⬜");
    }

    #[test]
    fn round1_rounds_to_one_decimal() {
        assert_eq!(round1(33.333), 33.3);
        assert_eq!(round1(0.0), 0.0);
    }
}
