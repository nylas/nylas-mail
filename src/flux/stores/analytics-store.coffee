_ = require 'underscore-plus'
Reflux = require 'reflux'
Mixpanel = require 'mixpanel'

Actions = require '../actions'
NamespaceStore = require './namespace-store'

module.exports =
AnalyticsStore = Reflux.createStore
  init: ->
    @listenAndTrack = (dispatcher=Actions) => (callback, action) =>
      @listenTo dispatcher[action], (args...) =>
        @track(action, callback(args...))

    @analytics = Mixpanel.init("625e2300ef07cb4eb70a69b3638ca579")
    @listenTo NamespaceStore, => @identify()
    @identify()

    @_listenToCoreActions()

    @_setupGlobalPackageActions()

  addPackageActions: (listeners, dispatcher=Actions) ->
    _.each listeners, @listenAndTrack(dispatcher)

  addGlobalPackageActions: (listeners) ->
    @_globalPackageActions = _.extend @_globalPackageActions, listeners

  _setupGlobalPackageActions: ->
    @_globalPackageActions = {}
    @listenTo Actions.sendToAllWindows, (actionData={}) =>
      return unless atom.isMainWindow()
      callback = @_globalPackageActions[actionData.action]
      if callback?
        @track(actionData.action, callback(actionData))

  # We white list actions to track.
  #
  # The Key is the action and the value is the callback function for that
  # action. That callback function should return the data we pass along to
  # our analytics service based on the sending data.
  #
  # IMPORTANT: Be VERY careful about what private data we send to our
  # analytics service!!
  #
  # Only completely anonymous data essential to future metrics or
  # debugging may be sent.
  coreWindowActions: ->
    showDeveloperConsole: -> {}
    composeReply: ({threadId, messageId}) -> {threadId, messageId}
    composeForward: ({threadId, messageId}) -> {threadId, messageId}
    composeReplyAll: ({threadId, messageId}) -> {threadId, messageId}
    composePopoutDraft: (draftLocalId) -> {draftLocalId: draftLocalId}
    composeNewBlankDraft: -> {}
    sendDraft: (draftLocalId) -> {draftLocalId: draftLocalId}
    destroyDraft: (draftLocalId) -> {draftLocalId: draftLocalId}
    searchQueryCommitted: (query) -> {}
    fetchAndOpenFile: -> {}
    fetchAndSaveFile: -> {}
    abortDownload: -> {}
    fileDownloaded: -> {}

  coreGlobalActions: ->
    logout: -> {}
    fileAborted: (uploadData={}) -> {fileSize: uploadData.fileSize}
    fileUploaded: (uploadData={}) -> {fileSize: uploadData.fileSize}
    sendDraftSuccess: ({draftLocalId}) -> {draftLocalId: draftLocalId}

  track: (action, data={}) ->
    @analytics.track(action, _.extend(data, namespaceId: NamespaceStore.current()?.id))

  identify: ->
    namespace = NamespaceStore.current()
    if namespace
      @analytics.alias("distinct_id", namespace.id)
      @analytics.people.set namespace.id,
        "$email": namespace.me().email
        "$first_name": namespace.me().firstName()
        "$last_name": namespace.me().lastName()
        "namespaceId": namespace.id

  _listenToCoreActions: ->
    _.each @coreWindowActions(), @listenAndTrack()
    _.each @coreGlobalActions(), @listenAndTrack() if atom.isMainWindow()
