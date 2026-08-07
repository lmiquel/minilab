import booklet
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import minilab_helper/commons.{format_date_fr}
import minilab_helper/monitoring
import simplifile

const report_path = "/host/ssd/backups/last-run.log"

const poll_interval_ms = 300_000

pub type BackupStatus {
  BackupOk
  BackupSkipped
  BackupMissing
  BackupFailed
}

pub type BackupEntry {
  BackupEntry(name: String, status: BackupStatus)
}

pub type BackupReport {
  BackupReport(timestamp: Int, entries: List(BackupEntry))
}

pub type Tick {
  Tick
}

type PollingState {
  PollingState(
    self: Subject(Tick),
    last_seen: booklet.Booklet(Option(Int)),
    bot: bot.Bot,
    owner_id: Snowflake(snowflake.User),
  )
}

pub fn start(
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
) -> Result(actor.Started(Subject(Tick)), actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send_after(subject, poll_interval_ms, Tick)

    actor.initialised(PollingState(
      self: subject,
      last_seen: booklet.new(None),
      bot: bot,
      owner_id: owner_id,
    ))
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(
  state: PollingState,
  msg: Tick,
) -> actor.Next(PollingState, Tick) {
  case msg {
    Tick -> {
      check_for_new_report(state.last_seen, state.bot, state.owner_id)
      process.send_after(state.self, poll_interval_ms, Tick)
      actor.continue(state)
    }
  }
}

fn read_report() -> Result(BackupReport, Nil) {
  use raw <- result.try(
    simplifile.read(from: report_path) |> result.replace_error(Nil),
  )
  parse_report(raw)
}

/// Port pur de la logique de parsing — séparé de `read_report` pour rester
/// testable sans dépendre de `/host/ssd`.
pub fn parse_report(raw: String) -> Result(BackupReport, Nil) {
  case string.split(string.trim(raw), "\n") {
    [] -> Error(Nil)
    [timestamp, ..lines] -> {
      use timestamp <- result.try(int.parse(timestamp))
      Ok(BackupReport(
        timestamp: timestamp,
        entries: list.filter_map(lines, parse_entry),
      ))
    }
  }
}

fn parse_entry(line: String) -> Result(BackupEntry, Nil) {
  use #(name, status) <- result.try(string.split_once(line, ":"))
  use status <- result.try(status_from_string(status))
  Ok(BackupEntry(name: name, status: status))
}

fn status_from_string(status: String) -> Result(BackupStatus, Nil) {
  case status {
    "ok" -> Ok(BackupOk)
    "skip" -> Ok(BackupSkipped)
    "missing" -> Ok(BackupMissing)
    "fail" -> Ok(BackupFailed)
    _ -> Error(Nil)
  }
}

/// Si un nouveau rapport est apparu depuis la dernière vérification (horodatage
/// différent de celui vu au tour précédent), envoie un DM récapitulatif et met
/// à jour l'horodatage vu — sinon ne fait rien.
fn check_for_new_report(
  last_seen: booklet.Booklet(Option(Int)),
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
) -> Nil {
  case read_report() {
    Error(Nil) -> Nil
    Ok(report) ->
      case booklet.get(last_seen) == Some(report.timestamp) {
        True -> Nil
        False -> {
          booklet.set(last_seen, Some(report.timestamp))
          monitoring.dm(bot, owner_id, format_report(report))
        }
      }
  }
}

fn format_report(report: BackupReport) -> String {
  let lines =
    list.map(report.entries, fn(entry) {
      status_emoji(entry.status) <> " " <> format_name(entry.name)
    })

  "💾 **Rapport de backup — "
  <> format_date_fr(report.timestamp)
  <> "**\n"
  <> string.join(lines, "\n")
}

fn format_name(name: String) -> String {
  string.replace(name, "-", " ") |> string.capitalise
}

fn status_emoji(status: BackupStatus) -> String {
  case status {
    BackupOk -> "✅"
    BackupSkipped -> "➖"
    BackupMissing -> "❓"
    BackupFailed -> "❌"
  }
}
