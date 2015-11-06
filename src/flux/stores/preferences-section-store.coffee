_ = require 'underscore'
NylasStore = require 'nylas-store'

class SectionConfig
  constructor: (opts={}) ->
    opts.order ?= Infinity
    _.extend(@, opts)

  nameOrUrl: ->
    if _.isFunction(@icon)
      icon = @icon()
    else
      icon = @icon

    if icon.indexOf("nylas://") is 0
      return {url: icon}
    else
      return {name: icon}

class PreferencesSectionStore extends NylasStore
  constructor: ->
    @_sectionConfigs = []
    @_accumulateAndTrigger ?= _.debounce(( => @trigger()), 20)
    @Section = {}
    @SectionConfig = SectionConfig

  sections: =>
    @_sectionConfigs

  # TODO: Use our <GeneratedForm /> Class
  # TODO: Add in a "richtext" input type in addition to standard input
  # types.
  registerPreferences: (packageId, config) ->
    throw new Error("Not implemented yet")

  unregisterPreferences: (packageId) ->
    throw new Error("Not implemented yet")

  ###
  Public: Register a new top-level section to preferences

  - `sectionConfig` a `PreferencesSectionStore.SectionConfig` object
    - `icon` A `nylas://` url or image name. Can be a function that
    resolves to one of these
    schema definitions on the PreferencesSectionStore.Section.MySectionId
    - `sectionId` A unique name to access the Section by
    - `displayName` The display name. This may go through i18n.
    - `component` The Preference section's React Component.

  Most Preference sections include an area where a {PreferencesForm} is
  rendered. This is a type of {GeneratedForm} that uses the schema passed
  into {PreferencesSectionStore::registerPreferences}

  Note that `icon` gets passed into the `url` field of a {RetinaImg}. This
  will, in an ideal case, expect to find the following images:

  - my-icon-darwin@1x.png
  - my-icon-darwin@2x.png
  - my-icon-win32@1x.png
  - my-icon-win32@2x.png

  ###
  registerPreferenceSection: (sectionConfig) ->
    @Section[sectionConfig.sectionId] = sectionConfig.sectionId
    @_sectionConfigs.push(sectionConfig)
    @_sectionConfigs = _.sortBy(@_sectionConfigs, "order")
    @_accumulateAndTrigger()

  unregisterPreferenceSection: (sectionId) ->
    delete @Section[sectionId]
    @_sectionConfigs = _.reject @_sectionConfigs, (sectionConfig) ->
      sectionConfig.sectionId is sectionId
    @_accumulateAndTrigger()

module.exports = new PreferencesSectionStore()
