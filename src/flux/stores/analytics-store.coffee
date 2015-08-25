_ = require 'underscore'
Reflux = require 'reflux'
Mixpanel = require 'mixpanel'

Actions = require '../actions'
AccountStore = require './account-store'

printToConsole = false

module.exports =
AnalyticsStore = Reflux.createStore
  init: ->
    @listenAndTrack = (dispatcher=Actions) => (callback, action) =>
      @listenTo dispatcher[action], (args...) =>
        @track(action, callback(args...))

    @analytics = Mixpanel.init("625e2300ef07cb4eb70a69b3638ca579")
    @listenTo AccountStore, => @identify()
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
    abortFetchFile: -> {}
    fileDownloaded: -> {}

  coreGlobalActions: ->
    fileAborted: (uploadData={}) -> {fileSize: uploadData.fileSize}
    fileUploaded: (uploadData={}) -> {fileSize: uploadData.fileSize}
    sendDraftSuccess: ({draftLocalId}) -> {draftLocalId: draftLocalId}

  track: (action, data={}) ->
    _.defer =>
      # send to the analytics service
      @analytics.track(action, _.extend(data, {
        accountId: AccountStore.current()?.id
        distinct_id: AccountStore.current()?.id
      }))

      # send to the logs that we ship to LogStash
      console.debug(printToConsole, {action, data})

  identify: ->
    account = AccountStore.current()
    if account
      @analytics.alias("distinct_id", account.id)
      @analytics.people.set account.id,
        "$email": account.me().email
        "$first_name": account.me().firstName()
        "$last_name": account.me().lastName()
        "accountId": account.id

  _listenToCoreActions: ->
    _.each @coreWindowActions(), @listenAndTrack()
    _.each @coreGlobalActions(), @listenAndTrack() if atom.isMainWindow()
