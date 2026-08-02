import gleam/float
import gleam/int
import gleam/result
import gleam/string
import simplifile

const thermal_zone_path = "/sys/class/thermal/thermal_zone0/temp"

/// Lit la température du RPi en °C (le fichier contient des millidegrés).
pub fn get_rpi_temperature() -> Result(Int, Nil) {
  use raw <- result.try(
    simplifile.read(from: thermal_zone_path) |> result.replace_error(Nil),
  )
  use millidegrees <- result.try(
    string.trim(raw) |> int.parse |> result.replace_error(Nil),
  )

  Ok(float.round(int.to_float(millidegrees) /. 1000.0))
}
