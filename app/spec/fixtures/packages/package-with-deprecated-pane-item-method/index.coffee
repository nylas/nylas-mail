class TestItem
  getUri: -> "test"

exports.activate = ->
  AppEnv.workspace.addOpener -> new TestItem
