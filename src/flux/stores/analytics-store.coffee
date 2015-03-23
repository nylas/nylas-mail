_ = require 'underscore-plus'
Reflux = require 'reflux'
Mixpanel = require 'mixpanel'

Actions = require '../actions'
NamespaceStore = require './namespace-store'

module.exports =
AnalyticsStore = Reflux.createStore
  init: ->
    @analytics = Mixpanel.init("625e2300ef07cb4eb70a69b3638ca579")
    @listenTo NamespaceStore, => @identify()
    @identify()

    @_listenToActions()

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
  actionsToTrack: ->
    logout: -> {}
    fileAborted: (uploadData={}) -> {fileSize: uploadData.fileSize}
    fileUploaded: (uploadData={}) -> {fileSize: uploadData.fileSize}
    sendDraftError: (dId, msg) -> {drafLocalId: dId, error: msg}
    sendDraftSuccess: (draftLocalId) -> {draftLocalId: draftLocalId}
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

  track: (action, data={}) ->
    return unless @id
    @analytics.track(action, _.extend(data, namespaceId: @id))

  identify: ->
    @id = NamespaceStore.current?()?.id?
    return unless @id
    me = NamespaceStore.current().me()
    @analytics.people.set @id,
      "$email": me.email
      "$first_name": me.firstName()
      "$last_name": me.lastName()
      "namespaceId": me.namespaceId

  _listenToActions: ->
    _.each @actionsToTrack(), (callback, action) =>
      @listenTo Actions[action], (args...) =>
        @track(action, callback(args...))
