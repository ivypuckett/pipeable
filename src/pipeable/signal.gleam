import pipeable/runnable.{type Runnable}

/// How a Signal is triggered.
pub type SignalTrigger {
  /// The signal is checked at a regular polling interval (in milliseconds).
  Polled(interval_ms: Int)
  /// The signal is triggered via an incoming webhook at the given path.
  Webhook(path: String)
}

/// A Signal pairs a Runnable with a trigger mechanism.
/// Signals are polled in parallel at the pipeline level.
pub type Signal {
  Signal(runnable: Runnable, trigger: SignalTrigger)
}

/// An unordered collection of associated Signals.
pub type SignalList =
  List(Signal)
