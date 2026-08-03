import minilab_helper/backup_report/private.{parse_report}
import minilab_helper/backup_report/types.{
  BackupEntry, BackupFailed, BackupMissing, BackupOk, BackupReport,
  BackupSkipped,
}

pub fn parses_a_real_last_run_log_test() {
  let raw =
    "2026-08-03T18:11:25+00:00
valheim:ok
cobblemon:missing
mariadb:ok
pihole:fail
duckdns:skip
"

  assert parse_report(raw)
    == Ok(
      BackupReport(timestamp: "2026-08-03T18:11:25+00:00", entries: [
        BackupEntry("valheim", BackupOk),
        BackupEntry("cobblemon", BackupMissing),
        BackupEntry("mariadb", BackupOk),
        BackupEntry("pihole", BackupFailed),
        BackupEntry("duckdns", BackupSkipped),
      ]),
    )
}

pub fn unknown_status_lines_are_dropped_test() {
  let raw = "2026-08-03T18:11:25+00:00\nvalheim:ok\nweird:???\n"

  assert parse_report(raw)
    == Ok(
      BackupReport(timestamp: "2026-08-03T18:11:25+00:00", entries: [
        BackupEntry("valheim", BackupOk),
      ]),
    )
}

pub fn an_empty_report_has_no_entries_test() {
  assert parse_report("2026-08-03T18:11:25+00:00\n")
    == Ok(BackupReport(timestamp: "2026-08-03T18:11:25+00:00", entries: []))
}

pub fn an_empty_string_has_an_empty_timestamp_and_no_entries_test() {
  assert parse_report("") == Ok(BackupReport(timestamp: "", entries: []))
}
