pub type DockerError {
  HttpError(String)
  UnexpectedStatus(Int, String)
  DecodeError(String)
}
