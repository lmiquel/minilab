import minilab_helper/backup_report.{
  BackupEntry, BackupFailed, BackupMissing, BackupOk, BackupReport,
  BackupSkipped, format_report, is_reboot_pending, parse_boot_time, parse_report,
}

pub fn the_maintenance_report_shows_sending_date_reboot_then_backup_test() {
  let report =
    BackupReport(timestamp: 1_796_094_000, entries: [
      BackupEntry("pingvin-data", BackupOk),
      BackupEntry("mariadb", BackupMissing),
    ])

  assert format_report(report, Ok(1_796_094_450), 1_796_095_200)
    == "🛠️ **Rapport de maintenance — 01/12/2026 04:20:00**
🔄 Dernier reboot : 01/12/2026 04:07:30
💾 Backup — 01/12/2026 04:00:00
✅ Pingvin data
❓ Mariadb"
}

pub fn an_unknown_last_reboot_is_said_explicitly_test() {
  let report = BackupReport(timestamp: 1_796_094_000, entries: [])

  assert format_report(report, Error(Nil), 1_796_095_200)
    == "🛠️ **Rapport de maintenance — 01/12/2026 04:20:00**
🔄 Dernier reboot : inconnu
💾 Backup — 01/12/2026 04:00:00
"
}

pub fn parses_the_boot_time_from_proc_stat_test() {
  let raw =
    "cpu  4705 356 584 3699 23 23 0 0 0 0
intr 1462898 0 0
ctxt 2307766
btime 1796094450
processes 6372
"

  assert parse_boot_time(raw) == Ok(1_796_094_450)
}

pub fn a_proc_stat_without_btime_fails_test() {
  assert parse_boot_time("cpu  4705 356 584 3699\n") == Error(Nil)
}

pub fn a_fresh_reboot_marker_holds_the_report_test() {
  assert is_reboot_pending("1796094000\n", 1_796_094_000 + 1800)
}

pub fn a_reboot_marker_older_than_six_hours_is_ignored_test() {
  assert !is_reboot_pending("1796094000\n", 1_796_094_000 + 6 * 3600)
}

pub fn an_unreadable_reboot_marker_is_ignored_test() {
  assert !is_reboot_pending("", 1_796_094_000)
}

pub fn parses_a_real_last_run_log_test() {
  let raw =
    "1754280685
valheim:ok
cobblemon:missing
mariadb:ok
pihole:fail
duckdns:skip
"

  assert parse_report(raw)
    == Ok(
      BackupReport(timestamp: 1_754_280_685, entries: [
        BackupEntry("valheim", BackupOk),
        BackupEntry("cobblemon", BackupMissing),
        BackupEntry("mariadb", BackupOk),
        BackupEntry("pihole", BackupFailed),
        BackupEntry("duckdns", BackupSkipped),
      ]),
    )
}

pub fn unknown_status_lines_are_dropped_test() {
  let raw = "1754280685\nvalheim:ok\nweird:???\n"

  assert parse_report(raw)
    == Ok(
      BackupReport(timestamp: 1_754_280_685, entries: [
        BackupEntry("valheim", BackupOk),
      ]),
    )
}

pub fn an_empty_report_has_no_entries_test() {
  assert parse_report("1754280685\n")
    == Ok(BackupReport(timestamp: 1_754_280_685, entries: []))
}

pub fn a_non_numeric_timestamp_fails_to_parse_test() {
  assert parse_report("") == Error(Nil)
  assert parse_report("not-a-timestamp\nvalheim:ok\n") == Error(Nil)
}
