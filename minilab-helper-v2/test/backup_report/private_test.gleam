import minilab_helper/backup_report/private.{parse_report}
import minilab_helper/backup_report/types.{
  BackupEntry, BackupFailed, BackupMissing, BackupOk, BackupReport,
  BackupSkipped,
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
