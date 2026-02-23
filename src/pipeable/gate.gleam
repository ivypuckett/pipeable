import pipeable/runnable.{type RunnableList}

/// An InputGate is a set of checks that must all return exit code 0
/// before a Node begins executing. The `required_edges` list specifies
/// which upstream Node names must have completed successfully.
pub type InputGate {
  InputGate(checks: RunnableList, required_edges: List(String))
}

/// An OutputGate is a set of checks that must all return exit code 0
/// before a Node signals completion.
pub type OutputGate {
  OutputGate(checks: RunnableList)
}
