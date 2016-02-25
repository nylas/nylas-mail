{PreferencesUIStore, ExtensionRegistry} = require 'nylas-exports'
SignatureComposerExtension = require './signature-composer-extension'
SignatureStore = require './signature-store'

module.exports =
  activate: ->
    @preferencesTab = new PreferencesUIStore.TabItem
      tabId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

    ExtensionRegistry.Composer.register(SignatureComposerExtension)
    PreferencesUIStore.registerPreferencesTab(@preferencesTab)

    @signatureStore = new SignatureStore()
    @signatureStore.activate()

  deactivate: ->
    ExtensionRegistry.Composer.unregister(SignatureComposerExtension)
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)
    @signatureStore.deactivate()

  serialize: ->
