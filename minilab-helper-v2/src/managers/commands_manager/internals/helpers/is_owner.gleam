import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import gleam/option.{None, Some}
import gleam/order

pub fn is_owner(
  pkt: InteractionCreatePacketData,
  owner_id: Snowflake(snowflake.User),
) -> Bool {
  case pkt.user, pkt.member {
    Some(user), _ -> snowflake.compare(user.id, owner_id) == order.Eq
    None, Some(member) ->
      snowflake.compare(member.user.id, owner_id) == order.Eq
    None, None -> False
  }
}
