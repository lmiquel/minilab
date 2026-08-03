import minilab_helper/commons.{format_date_fr}

pub fn winter_uses_cet_utc_plus_1_test() {
  // 2026-01-15 12:00:00 UTC
  assert format_date_fr(1_768_478_400) == "15/01/2026 13:00:00"
}

pub fn summer_uses_cest_utc_plus_2_test() {
  // 2026-07-15 12:00:00 UTC
  assert format_date_fr(1_784_116_800) == "15/07/2026 14:00:00"
}

pub fn just_before_spring_forward_is_still_cet_test() {
  // 2026-03-29 00:59:00 UTC — bascule DST à 01:00 UTC ce jour-là
  assert format_date_fr(1_774_745_940) == "29/03/2026 01:59:00"
}

pub fn spring_forward_switches_to_cest_test() {
  // 2026-03-29 01:00:00 UTC
  assert format_date_fr(1_774_746_000) == "29/03/2026 03:00:00"
}

pub fn just_before_fall_back_is_still_cest_test() {
  // 2026-10-25 00:59:00 UTC — bascule DST à 01:00 UTC ce jour-là
  assert format_date_fr(1_792_889_940) == "25/10/2026 02:59:00"
}

pub fn fall_back_switches_to_cet_test() {
  // 2026-10-25 01:00:00 UTC
  assert format_date_fr(1_792_890_000) == "25/10/2026 02:00:00"
}
