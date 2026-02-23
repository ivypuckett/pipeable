import pipeable/stage.{type Stage}

/// A Node in the Pipeline is either a Stage (a unit of work) or a reference
/// to a nested Pipeline, enabling Pipeline composition.
pub type Node {
  StageNode(stage: Stage)
  PipelineRef(name: String)
}

/// Returns the name of a Node.
pub fn name(node: Node) -> String {
  case node {
    StageNode(s) -> s.name
    PipelineRef(pipeline_name) -> pipeline_name
  }
}
