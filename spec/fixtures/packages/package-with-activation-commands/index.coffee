module.exports =
  activateCallCount: 0
  activationCommandCallCount: 0
  legacyActivationCommandCallCount: 0

  activate: ->
    @activateCallCount++

    NylasEnv.commands.add 'nylas-workspace', 'activation-command', =>
      @activationCommandCallCount++

    editorView = NylasEnv.views.getView(NylasEnv.workspace.getActiveTextEditor())?.__spacePenView
    editorView?.command 'activation-command', =>
      @legacyActivationCommandCallCount++
