import gleam/option.{type Option}

pub type KlippyState {
  Ready
  Startup
  Shutdown
  Error
}

pub type ThrottledState {
  ThrottledState(bits: Int)
}

pub type PrinterStorageInfo {
  PrinterStorageInfo(used_gb: Float, total_gb: Float, percent: Float)
}

pub type MiniPrintOverview {
  MiniPrintOverview(
    reachable: Bool,
    cpu_temp_c: Option(Float),
    cpu_percent: Option(Float),
    moonraker_mem_mb: Option(Int),
    total_mem_mb: Option(Int),
    uptime_sec: Option(Int),
    throttled: Option(ThrottledState),
    storage: Option(PrinterStorageInfo),
    mainsail_up: Bool,
    moonraker_up: Bool,
    klippy_state: Option(KlippyState),
    crowsnest_up: Bool,
  )
}
