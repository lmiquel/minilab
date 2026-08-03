import gleam/erlang/atom
import gleam/int
import gleam/option.{type Option}
import minilab_helper/dictionaries/docker_services.{type ServiceName}

// ── Types ────────────────────────────────────────────────────────────────

pub type HealthStatus {
  Healthy
  Unhealthy
  Starting
  NoHealthcheck
}

pub fn health_status_to_string(status: HealthStatus) -> String {
  case status {
    Healthy -> "healthy"
    Unhealthy -> "unhealthy"
    Starting -> "starting"
    NoHealthcheck -> "none"
  }
}

pub fn health_emoji(status: HealthStatus) -> String {
  case status {
    Healthy -> "💚"
    Unhealthy -> "❤️‍🩹"
    Starting -> "⏳"
    NoHealthcheck -> "⬜"
  }
}

pub type ContainerStatus {
  ContainerStatus(
    name: ServiceName,
    state: String,
    restart_count: Int,
    health: HealthStatus,
  )
}

pub type ResourceUsage {
  ResourceUsage(cpu_percent: Float, mem_usage_mb: Int, mem_percent: Float)
}

pub type HostResources {
  HostResources(
    cpu_percent: Float,
    mem_used_mb: Int,
    mem_total_mb: Int,
    mem_percent: Float,
  )
}

pub type HostStorageInfo {
  HostStorageInfo(used_gb: Float, total_gb: Float, percent: Float)
}

pub type HostStorageUsage {
  HostStorageUsage(sd: HostStorageInfo, ssd: HostStorageInfo)
}

pub type PeerInfo {
  PeerInfo(name: String, connected: Bool, last_handshake: Option(Int))
}

// ── Heure ────────────────────────────────────────────────────────────────

/// Timestamp unix courant, en secondes.
pub fn now() -> Int {
  os_system_time(atom.create("second"))
}

@external(erlang, "os", "system_time")
fn os_system_time(unit: atom.Atom) -> Int

/// Formate un timestamp unix (secondes) en heure locale Europe/Paris,
/// au format `JJ/MM/AAAA HH:MM:SS` — approximation pure Gleam de
/// `date.toLocaleString("fr-FR", {timeZone: "Europe/Paris"})` du v1.
/// Aucune dépendance externe : les bibliothèques Gleam de date/heure
/// disponibles n'ont pas de support fuseau horaire nommé assez mûr
/// (vérifié : `sidereal`, `tempo`) pour un simple besoin d'affichage.
pub fn format_date_fr(timestamp: Int) -> String {
  let local_ts = timestamp + paris_offset_seconds(timestamp)

  let days_since_epoch = floor_div(local_ts, 86_400)
  let seconds_of_day = floor_mod(local_ts, 86_400)

  let #(year, month, day) = civil_from_days(days_since_epoch)
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = seconds_of_day % 60

  pad2(day)
  <> "/"
  <> pad2(month)
  <> "/"
  <> int.to_string(year)
  <> " "
  <> pad2(hour)
  <> ":"
  <> pad2(minute)
  <> ":"
  <> pad2(second)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

/// Décalage Europe/Paris en secondes pour un instant UTC donné : +2h (CEST)
/// entre le dernier dimanche de mars 01:00 UTC et le dernier dimanche
/// d'octobre 01:00 UTC, +1h (CET) le reste de l'année — règle UE stable
/// depuis 1996.
fn paris_offset_seconds(timestamp: Int) -> Int {
  case is_cest(timestamp) {
    True -> 2 * 3600
    False -> 1 * 3600
  }
}

fn is_cest(timestamp: Int) -> Bool {
  let #(year, _, _) = civil_from_days(floor_div(timestamp, 86_400))
  let dst_start = last_sunday_days(year, 3) * 86_400 + 3600
  let dst_end = last_sunday_days(year, 10) * 86_400 + 3600
  timestamp >= dst_start && timestamp < dst_end
}

/// Jours depuis l'epoch (1970-01-01) du dernier dimanche du mois donné.
fn last_sunday_days(year: Int, month: Int) -> Int {
  let last_day = days_in_month(year, month)
  let last_day_z = days_from_civil(year, month, last_day)
  last_day_z - day_of_week(last_day_z)
}

/// 0 = dimanche .. 6 = samedi. 1970-01-01 (z=0) était un jeudi.
fn day_of_week(z: Int) -> Int {
  floor_mod(z + 4, 7)
}

fn is_leap_year(year: Int) -> Bool {
  { year % 4 == 0 } && { year % 100 != 0 || year % 400 == 0 }
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    4 | 6 | 9 | 11 -> 30
    _ ->
      case is_leap_year(year) {
        True -> 29
        False -> 28
      }
  }
}

/// Algorithme civil_from_days / days_from_civil de Howard Hinnant — valide
/// pour toute date proleptique grégorienne. On reste sur une division
/// entière classique (troncature) plutôt qu'un plancher explicite : pour
/// tout usage réel de ce bot (dates après 1970), les opérandes sont
/// toujours positifs, donc les deux coïncident.
fn civil_from_days(z: Int) -> #(Int, Int, Int) {
  let z = z + 719_468
  let era = z / 146_097
  let doe = z - era * 146_097
  let yoe = { doe - doe / 1460 + doe / 36_524 - doe / 146_096 } / 365
  let y = yoe + era * 400
  let doy = doe - { 365 * yoe + yoe / 4 - yoe / 100 }
  let mp = { 5 * doy + 2 } / 153
  let d = doy - { 153 * mp + 2 } / 5 + 1
  let m = case mp < 10 {
    True -> mp + 3
    False -> mp - 9
  }
  let y = case m <= 2 {
    True -> y + 1
    False -> y
  }
  #(y, m, d)
}

fn days_from_civil(year: Int, month: Int, day: Int) -> Int {
  let y = case month <= 2 {
    True -> year - 1
    False -> year
  }
  let era = floor_div(y, 400)
  let yoe = y - era * 400
  let extra_month = case month > 2 {
    True -> -3
    False -> 9
  }
  let doy = { 153 * { month + extra_month } + 2 } / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146_097 + doe - 719_468
}

fn floor_div(a: Int, b: Int) -> Int {
  case a % b == 0 || { a > 0 } == { b > 0 } {
    True -> a / b
    False -> a / b - 1
  }
}

fn floor_mod(a: Int, b: Int) -> Int {
  a - floor_div(a, b) * b
}
