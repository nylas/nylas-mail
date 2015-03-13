{ComponentRegistry} = require 'inbox-exports'
ModeSwitch = require './mode-switch'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'ModeSwitch'
      view: ModeSwitch
      role: 'Root:Toolbar'
