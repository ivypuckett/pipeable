import gleam/option.{type Option, None}
import pipeable/gate.{type InputGate, type OutputGate}
import pipeable/runnable.{type RunnableList}
import pipeable/signal.{type SignalList}

/// A Rollback defines the conditions that trigger it and the steps to execute
/// when rolling back a Stage.
pub type Rollback {
  Rollback(triggers: SignalList, steps: RunnableList)
}

/// The executable body of a Stage.
pub type StageBody {
  /// A root Stage is driven by Signals rather than upstream nodes.
  SignalDriven(signals: SignalList)
  /// A standard Stage has forward execution steps and an optional rollback.
  Executable(forward: RunnableList, rollback: Option(Rollback))
}

/// A Stage is a named unit of work in the Pipeline.
pub type Stage {
  Stage(
    name: String,
    body: StageBody,
    input_gate: Option(InputGate),
    output_gate: Option(OutputGate),
  )
}

/// Creates a simple executable Stage with no gates and no rollback.
pub fn simple(name: String, forward: RunnableList) -> Stage {
  Stage(
    name: name,
    body: Executable(forward: forward, rollback: None),
    input_gate: None,
    output_gate: None,
  )
}
