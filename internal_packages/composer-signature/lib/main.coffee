{PreferencesUIStore, DraftStore} = require 'nylas-exports'
SignatureDraftExtension = require './signature-draft-extension'

module.exports =
  activate: (@state={}) ->
    @preferencesTab = new PreferencesUIStore.TabItem
      tabId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

    DraftStore.registerExtension(SignatureDraftExtension)
    PreferencesUIStore.registerPreferencesTab(@preferencesTab)

  deactivate: ->
    DraftStore.unregisterExtension(SignatureDraftExtension)
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)

  serialize: -> @state
