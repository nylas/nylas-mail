{PreferencesSectionStore, DraftStore} = require 'nylas-exports'
SignatureDraftExtension = require './signature-draft-extension'

module.exports =
  activate: (@state={}) ->
    DraftStore.registerExtension(SignatureDraftExtension)

    @sectionConfig = new PreferencesSectionStore.SectionConfig
      # TODO: Fix RetinaImg to handle plugin images
      icon: ->
        if process.platform is "win32"
          "nylas://composer-signature/images/ic-settings-signatures-win32@2x.png"
        else
          "nylas://composer-signature/images/ic-settings-signatures@2x.png"
      sectionId: "Signatures"
      displayName: "Signatures"
      component: require "./preferences-signatures"

    PreferencesSectionStore.registerPreferenceSection(@sectionConfig)

    ## TODO:
    # PreferencesSectionStore.registerPreferences "composer-signatures", [
    #   {
    #     section: PreferencesSectionStore.Section.Signatures
    #     type: "richtext"
    #     label: "Signature:"
    #     perAccount: true
    #     defaultValue: "- Sent from N1"
    #   }, {
    #     section: PreferencesSectionStore.Section.Signatures
    #     type: "toggle"
    #     label: "Include on replies"
    #     defaultValue: true
    #   }
    # ]

  deactivate: ->
    DraftStore.unregisterExtension(SignatureDraftExtension)
    PreferencesSectionStore.unregisterPreferenceSection(@sectionConfig.sectionId)

  serialize: -> @state
