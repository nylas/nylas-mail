class TestItem
  getUri: -> "test"

exports.activate = ->
  NylasEnv.workspace.addOpener -> new TestItem
