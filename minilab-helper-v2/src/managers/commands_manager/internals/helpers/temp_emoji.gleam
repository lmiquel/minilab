pub fn temp_emoji(celsius: Int) -> String {
  case celsius >= 70 {
    True -> "🔴"
    False ->
      case celsius >= 60 {
        True -> "🟡"
        False -> "🟢"
      }
  }
}
