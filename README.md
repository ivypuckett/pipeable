# pipeable

An easy, efficient, fully-featured cicd pipeline in one executable. Think PocketBase for CI/CD.

## Status: Ideation

Nothing to see yet, but follow along if you like.

## Goals

- Always free and open source. Supported through donations.
- Run anywhere with one binary.
- Always declarative, always idempotent*. (*developers have a responsibility to create idempotent plugins)
- Best practices out of the box.
- Validates dependencies before running with automatic dependency detection.
- Visualize things before rolling out the new deployment.
- Visualize current pipeline state.
- Edit with a visual editor inside of your favorite IDE.
- Distributed package management with the ability to freeze a set of dependencies. (Think how Go does things)
 
## Concepts

1. Pipeline: A directed, acyclic graph of Nodes connected through Edges.
2. Node: a Stage in a Pipeline or a Pipeline.
3. Edge: A connection between Nodes.
4. Runnable: Executables and scripts which must be fully qualified or live on the PATH. These may reference Contexts.
5. RunnableList: An ordered array of Runnables and RunnableParallelGroups.
6. RunnableParallelGroups: Runnables which can be run concurrently
7. Context: Files and environment variables which must be fully qualified or live on the PATH.
8. InputGate: A RunnableList which must return 0 before the Node will execute. Within the config, Edges are stored as part of the InputGate.
9. OutputGate: A RunnableList which must return 0 before signaling completion.
10. Stage: A SignalList (when Stage is positioned at a root node), a RunnableList for rolling forward and a Rollback. Also Input/Output Gates
11. Signal: A Runnable and a pollng interval or a webhook. Signals are polled in parallel at a pipeline level and can be connected to Input/Output Gates and Rollbacks to trigger aspects of the pipeline.
12. SignalList: An unordered array of associatedSignals
13. Rollback: A SignalList which triggers the rollback and a RunnableList to execute the rollback.
