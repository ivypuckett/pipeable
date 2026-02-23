import pipeable/context.{type Context}

/// A Runnable is an executable or script, fully qualified or on the PATH.
/// Runnables may reference Contexts for file paths and environment variables.
pub type Runnable {
  Runnable(command: String, args: List(String), contexts: List(Context))
}

/// A group of Runnables that may be executed concurrently.
pub type RunnableParallelGroup {
  RunnableParallelGroup(runnables: List(Runnable))
}

/// An item in a RunnableList — either a single sequential Runnable or
/// a group to be executed in parallel.
pub type RunnableListItem {
  Sequential(runnable: Runnable)
  Parallel(group: RunnableParallelGroup)
}

/// An ordered sequence of Runnables and RunnableParallelGroups.
pub type RunnableList =
  List(RunnableListItem)

/// Creates a simple Runnable with no arguments and no contexts.
pub fn simple(command: String) -> Runnable {
  Runnable(command: command, args: [], contexts: [])
}

/// Wraps a single Runnable into a RunnableList.
pub fn singleton(runnable: Runnable) -> RunnableList {
  [Sequential(runnable: runnable)]
}
