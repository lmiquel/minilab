import gleam/option.{None, Some}
import minilab_helper/commands/private.{
  format_uptime, klippy_state_emoji, temp_emoji_float,
}
import minilab_helper/miniprint/types as miniprint_types

pub fn format_uptime_under_a_minute_test() {
  assert format_uptime(0) == "0min"
}

pub fn format_uptime_minutes_only_test() {
  assert format_uptime(45 * 60) == "45min"
}

pub fn format_uptime_hours_and_minutes_test() {
  assert format_uptime(3 * 3600 + 12 * 60) == "3h 12min"
}

pub fn format_uptime_days_and_hours_test() {
  assert format_uptime(2 * 86_400 + 5 * 3600 + 30 * 60) == "2j 5h"
}

pub fn klippy_state_emoji_ready_test() {
  assert klippy_state_emoji(Some(miniprint_types.Ready)) == "🟢"
}

pub fn klippy_state_emoji_startup_test() {
  assert klippy_state_emoji(Some(miniprint_types.Startup)) == "🟡"
}

pub fn klippy_state_emoji_shutdown_test() {
  assert klippy_state_emoji(Some(miniprint_types.Shutdown)) == "🔴"
}

pub fn klippy_state_emoji_error_test() {
  assert klippy_state_emoji(Some(miniprint_types.Error)) == "🔴"
}

pub fn klippy_state_emoji_unreachable_test() {
  assert klippy_state_emoji(None) == "⚫"
}

pub fn temp_emoji_float_cold_test() {
  assert temp_emoji_float(45.3) == "🟢"
}

pub fn temp_emoji_float_warm_test() {
  assert temp_emoji_float(65.0) == "🟡"
}

pub fn temp_emoji_float_hot_test() {
  assert temp_emoji_float(72.8) == "🔴"
}

pub fn temp_emoji_float_boundary_test() {
  assert temp_emoji_float(70.0) == "🔴"
  assert temp_emoji_float(60.0) == "🟡"
}
