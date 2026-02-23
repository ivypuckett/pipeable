import gleam/list
import pipeable/edge.{type Edge}
import pipeable/node.{type Node}

/// A Pipeline is a directed acyclic graph of Nodes connected through Edges.
pub type Pipeline {
  Pipeline(name: String, nodes: List(Node), edges: List(Edge))
}

/// Returns the names of all Nodes in the Pipeline.
pub fn node_names(pipeline: Pipeline) -> List(String) {
  list.map(pipeline.nodes, node.name)
}

/// Returns all Edges originating from the given Node name.
pub fn edges_from(pipeline: Pipeline, from: String) -> List(Edge) {
  list.filter(pipeline.edges, fn(e) { e.from == from })
}

/// Returns all Edges pointing to the given Node name.
pub fn edges_to(pipeline: Pipeline, to: String) -> List(Edge) {
  list.filter(pipeline.edges, fn(e) { e.to == to })
}
