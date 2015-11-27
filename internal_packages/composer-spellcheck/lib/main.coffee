{ExtensionRegistry} = require 'nylas-exports'
SpellcheckComposerExtension = require './spellcheck-composer-extension'

module.exports =
  activate: (@state={}) ->
    ExtensionRegistry.Composer.register(SpellcheckComposerExtension)

  deactivate: ->
    ExtensionRegistry.Composer.unregister(SpellcheckComposerExtension)

  serialize: -> @state
