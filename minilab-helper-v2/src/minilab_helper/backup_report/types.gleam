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
  BackupReport(timestamp: String, entries: List(BackupEntry))
}
