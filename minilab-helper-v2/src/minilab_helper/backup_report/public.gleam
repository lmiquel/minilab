import booklet
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None}
import gleam/otp/actor
import minilab_helper/backup_report/private

const poll_interval_ms = 300_000

pub type Tick {
  Tick
}

type PollingState {
  PollingState(
    self: Subject(Tick),
    last_seen: booklet.Booklet(Option(String)),
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
      private.check_for_new_report(state.last_seen, state.bot, state.owner_id)
      process.send_after(state.self, poll_interval_ms, Tick)
      actor.continue(state)
    }
  }
}
