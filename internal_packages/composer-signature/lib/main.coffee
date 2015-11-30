{PreferencesUIStore, DraftStore} = require 'nylas-exports'
SignatureDraftExtension = require './signature-draft-extension'

module.exports =
  activate: (@state={}) ->
    DraftStore.registerExtension(SignatureDraftExtension)

    @preferencesTab = new PreferencesUIStore.TabItem
      tabId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

  deactivate: ->
    DraftStore.unregisterExtension(SignatureDraftExtension)
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)

  serialize: -> @state
