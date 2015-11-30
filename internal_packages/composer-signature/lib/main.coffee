{PreferencesUIStore, DraftStore} = require 'nylas-exports'
SignatureDraftExtension = require './signature-draft-extension'

module.exports =
  activate: (@state={}) ->
    DraftStore.registerExtension(SignatureDraftExtension)

    @preferencesTab = new PreferencesUIStore.TabItem
      # TODO: Fix RetinaImg to handle plugin images
      icon: ->
        if process.platform is "win32"
          "nylas://composer-signature/images/ic-settings-signatures-win32@2x.png"
        else
          "nylas://composer-signature/images/ic-settings-signatures@2x.png"
      tabId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

    # TODO Re-enable when fixed!
    # PreferencesUIStore.registerPreferencesTab(@preferencesTab)

    ## TODO
    # PreferencesUIStore.registerPreferences "composer-signatures", [
    #   {
    #     section: PreferencesUIStore.Section.Signatures
    #     type: "richtext"
    #     label: "Signature:"
    #     perAccount: true
    #     defaultValue: "- Sent from N1"
    #   }, {
    #     section: PreferencesUIStore.Section.Signatures
    #     type: "toggle"
    #     label: "Include on replies"
    #     defaultValue: true
    #   }
    # ]

  deactivate: ->
    DraftStore.unregisterExtension(SignatureDraftExtension)
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)

  serialize: -> @state
