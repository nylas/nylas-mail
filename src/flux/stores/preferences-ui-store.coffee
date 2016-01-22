_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
Actions = require '../actions'
Immutable = require 'immutable'

MAIN_TAB_ITEM_ID = 'General'

class TabItem
  constructor: (opts={}) ->
    opts.order ?= Infinity
    _.extend(@, opts)

class PreferencesUIStore extends NylasStore
  constructor: ->
    @_tabs = Immutable.List()
    @_selection = Immutable.Map({
      tabId: null
      accountId: AccountStore.current()?.id
    })

    @_triggerDebounced ?= _.debounce(( => @trigger()), 20)

    @listenTo AccountStore, =>
      @_selection = @_selection.set('accountId', AccountStore.current()?.id)
      @trigger()

    @listenTo Actions.switchPreferencesTab, (tabId, options = {}) =>
      @_selection = @_selection.set('tabId', tabId)
      if options.accountId
        @_selection = @_selection.set('accountId', options.accountId)
      @trigger()

  tabs: =>
    @_tabs

  selection: =>
    @_selection

  ###
  Public: Register a new top-level section to preferences

  - `tabItem` a `PreferencesUIStore.TabItem` object
    schema definitions on the PreferencesUIStore.Section.MySectionId
    - `tabId` A unique name to access the Section by
    - `displayName` The display name. This may go through i18n.
    - `component` The Preference section's React Component.

  Most Preference sections include an area where a {PreferencesForm} is
  rendered. This is a type of {GeneratedForm} that uses the schema passed
  into {PreferencesUIStore::registerPreferences}

  ###
  registerPreferencesTab: (tabItem) ->
    @_tabs = @_tabs.push(tabItem).sort (a, b) =>
      a.order > b.order
    if tabItem.tabId is MAIN_TAB_ITEM_ID
      @_selection = @_selection.set('tabId', tabItem.tabId)
    @_triggerDebounced()

  unregisterPreferencesTab: (tabItemOrId) ->
    @_tabs = @_tabs.filter (s) -> s.tabId isnt tabItemOrId and s isnt tabItemOrId
    @_triggerDebounced()

module.exports = new PreferencesUIStore()
module.exports.TabItem = TabItem
