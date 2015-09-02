{ComponentRegistry, DraftStore} = require 'nylas-exports'
Extension = require './draft-extension'

module.exports =
  activate: (@state={}) ->
    DraftStore.registerExtension(Extension)

  deactivate: ->
    DraftStore.unregisterExtension(Extension)

  serialize: -> @state
