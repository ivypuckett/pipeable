/// An Edge is a directed connection from one Node to another within a Pipeline.
/// The `from` and `to` fields reference Node names.
pub type Edge {
  Edge(from: String, to: String)
}
