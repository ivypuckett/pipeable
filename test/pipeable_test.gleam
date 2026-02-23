import gleam/option.{None}
import gleeunit
import gleeunit/should
import pipeable/context
import pipeable/edge
import pipeable/node
import pipeable/pipeline
import pipeable/runnable
import pipeable/stage

pub fn main() {
  gleeunit.main()
}

// --- runnable ---

pub fn runnable_simple_creates_empty_runnable_test() {
  let r = runnable.simple("echo")
  r.command |> should.equal("echo")
  r.args |> should.equal([])
  r.contexts |> should.equal([])
}

// --- context ---

pub fn context_file_variant_test() {
  let ctx = context.FileContext(path: "/etc/config.toml")
  ctx |> should.equal(context.FileContext(path: "/etc/config.toml"))
}

pub fn context_env_variant_test() {
  let ctx = context.EnvContext(variable: "DATABASE_URL")
  ctx |> should.equal(context.EnvContext(variable: "DATABASE_URL"))
}

// --- stage ---

pub fn stage_simple_has_correct_name_test() {
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  s.name |> should.equal("build")
}

pub fn stage_simple_has_no_gates_test() {
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  s.input_gate |> should.equal(None)
  s.output_gate |> should.equal(None)
}

pub fn stage_simple_has_no_rollback_test() {
  let r = runnable.simple("make")
  let s = stage.simple("build", [runnable.Sequential(r)])
  s.body |> should.equal(stage.Executable(forward: [runnable.Sequential(r)], rollback: None))
}

// --- node ---

pub fn node_name_returns_stage_name_test() {
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  node.StageNode(stage: s) |> node.name |> should.equal("build")
}

pub fn node_name_returns_pipeline_ref_name_test() {
  node.PipelineRef(name: "deploy") |> node.name |> should.equal("deploy")
}

// --- pipeline ---

pub fn pipeline_node_names_returns_all_names_test() {
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  let p = pipeline.Pipeline(
    name: "ci",
    nodes: [node.StageNode(stage: s), node.PipelineRef(name: "deploy")],
    edges: [],
  )
  pipeline.node_names(p) |> should.equal(["build", "deploy"])
}

pub fn pipeline_edges_from_filters_correctly_test() {
  let e = edge.Edge(from: "build", to: "deploy")
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  let p = pipeline.Pipeline(
    name: "ci",
    nodes: [node.StageNode(stage: s), node.PipelineRef(name: "deploy")],
    edges: [e],
  )
  pipeline.edges_from(p, "build") |> should.equal([e])
  pipeline.edges_from(p, "deploy") |> should.equal([])
}

pub fn pipeline_edges_to_filters_correctly_test() {
  let e = edge.Edge(from: "build", to: "deploy")
  let s = stage.simple("build", [runnable.Sequential(runnable.simple("make"))])
  let p = pipeline.Pipeline(
    name: "ci",
    nodes: [node.StageNode(stage: s), node.PipelineRef(name: "deploy")],
    edges: [e],
  )
  pipeline.edges_to(p, "deploy") |> should.equal([e])
  pipeline.edges_to(p, "build") |> should.equal([])
}
