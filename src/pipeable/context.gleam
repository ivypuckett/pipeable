/// A Context represents a file or environment variable that a Runnable
/// may reference. All file paths must be fully qualified or live on the PATH.
pub type Context {
  FileContext(path: String)
  EnvContext(variable: String)
}
