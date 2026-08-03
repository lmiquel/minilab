import booklet
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import minilab_helper/commons.{type PeerInfo}
import minilab_helper/docker/public as docker
import minilab_helper/wireguard/private
import minilab_helper/wireguard/types.{type ConnectedPeer, type WireGuardState}

const poll_interval_ms = 15_000

pub type Tick {
  Tick
}

type PollingState {
  PollingState(
    self: Subject(Tick),
    docker: docker.Client,
    wireguard_state: booklet.Booklet(WireGuardState),
    bot: bot.Bot,
    owner_id: Snowflake(snowflake.User),
  )
}

pub fn new_state() -> booklet.Booklet(WireGuardState) {
  booklet.new(types.new())
}

pub fn load_peer_names(
  docker: docker.Client,
  state: booklet.Booklet(WireGuardState),
  peers: List(String),
) -> Nil {
  private.load_peer_names(docker, state, peers)
}

pub fn start(
  docker: docker.Client,
  state: booklet.Booklet(WireGuardState),
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
) -> Result(actor.Started(Subject(Tick)), actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send_after(subject, poll_interval_ms, Tick)

    actor.initialised(PollingState(
      self: subject,
      docker: docker,
      wireguard_state: state,
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
      private.check_wireguard_handshakes(
        state.docker,
        state.wireguard_state,
        state.bot,
        state.owner_id,
      )
      process.send_after(state.self, poll_interval_ms, Tick)
      actor.continue(state)
    }
  }
}

pub fn get_all_peers(state: booklet.Booklet(WireGuardState)) -> List(PeerInfo) {
  private.get_all_peers(booklet.get(state))
}

pub fn get_connected_peers(
  state: booklet.Booklet(WireGuardState),
) -> List(ConnectedPeer) {
  private.get_connected_peers(booklet.get(state))
}
