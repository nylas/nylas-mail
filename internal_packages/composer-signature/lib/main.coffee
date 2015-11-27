{PreferencesUIStore, ExtensionRegistry} = require 'nylas-exports'
SignatureComposerExtension = require './signature-composer-extension'

module.exports =
  activate: (@state={}) ->
    @preferencesTab = new PreferencesUIStore.TabItem
      tabId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

    ExtensionRegistry.Composer.register(SignatureComposerExtension)
    PreferencesUIStore.registerPreferencesTab(@preferencesTab)

  deactivate: ->
    ExtensionRegistry.Composer.unregister(SignatureComposerExtension)
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)

  serialize: -> @state
