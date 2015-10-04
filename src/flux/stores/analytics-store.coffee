_ = require 'underscore'
Reflux = require 'reflux'
Mixpanel = require 'mixpanel'
qs = require 'querystring'

Actions = require '../actions'
AccountStore = require './account-store'

printToConsole = false

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
coreWindowActions =
  composeReply: -> ['Compose Draft', {'type': 'reply'}]
  composeForward: -> ['Compose Draft', {'type': 'forward'}]
  composeReplyAll: -> ['Compose Draft', {'type': 'reply-all'}]
  composeNewBlankDraft: -> ['Compose Draft', {'type': 'blank'}]
  composePopoutDraft: -> ['Popout Draft', {}]
  sendDraft: -> ['Send Draft', {}]
  destroyDraft: -> ['Delete Draft', {}]
  searchQueryCommitted: (query) -> ['Commit Search Query', {}]
  attachFile: -> ['Attach File', {}]
  attachFilePath: -> ['Attach File Path', {}]
  fetchAndOpenFile: -> ['Download and Open File', {}]
  fetchAndSaveFile: -> ['Download and Save File', {}]
  abortFetchFile: -> ['Cancel Download', {}]
  fileDownloaded: -> ['Download Complete', {}]

module.exports =
AnalyticsStore = Reflux.createStore

  init: ->
    @analytics = Mixpanel.init("9a2137b80c098b3d594e39b776ebe085")
    @listenTo Actions.sendFeedback, @_onSendFeedback
    @listenTo AccountStore, => @identify()
    @identify()

    @trackActions(Actions, coreWindowActions)
    @trackTasks()

  trackActions: (dispatcher, listeners) ->
    _.each listeners, (mappingFunction, actionName) =>
      @listenTo dispatcher[actionName], (args...) =>
        [eventName, eventArgs] = mappingFunction(args...)
        @track(eventName, eventArgs)

  trackTasks: ->
    @listenTo Actions.queueTask, (task) =>
      return unless task
      eventName = task.constructor.name
      eventArgs = {}
      eventArgs['item_count'] = task.messages.length if task.messages?
      eventArgs['item_count'] = task.threads.length if task.threads?
      @track(eventName, eventArgs)

  track: (eventName, eventArgs={}) ->
    _.defer =>
      # send to the analytics service
      @analytics.track(eventName, _.extend(eventArgs, {
        platform: process.platform
        version: atom.getVersion()
        distinct_id: AccountStore.current()?.id
        accountId: AccountStore.current()?.id
      }))

      # send to the logs that we ship to LogStash
      console.debug(printToConsole, {eventName, eventArgs})

  identify: ->
    account = AccountStore.current()
    if account
      @analytics.people.set(account.id, {
        "$email": account.me().email
        "$first_name": account.me().firstName()
        "$last_name": account.me().lastName()
        "accountId": account.id
        "platform": process.platform
        "provider": account.displayProvider()
        "organizational_unit": account.organizationUnit
        "version_primary": atom.getVersion().split('-')[0]
        "version": atom.getVersion()
      })
      @analytics.people.set_once(account.id, {
        "First Seen": (new Date()).toISOString()
      })

  _onSendFeedback: ->
    return if atom.inSpecMode()

    {AccountStore} = require 'nylas-exports'
    BrowserWindow = require('remote').require('browser-window')
    Screen = require('remote').require('screen')
    path = require 'path'

    account = AccountStore.current()
    params = qs.stringify({
      name: account.name
      email: account.emailAddress
      accountId: account.id
      accountProvider: account.provider
      platform: process.platform
      provider: account.displayProvider()
      organizational_unit: account.organizationUnit
      version: atom.getVersion()
    })

    parentBounds = atom.getCurrentWindow().getBounds()
    parentScreen = Screen.getDisplayMatching(parentBounds)

    width = 376
    height = Math.min(550, parentBounds.height)
    x = Math.min(parentScreen.workAreaSize.width - width, Math.max(0, parentBounds.x + parentBounds.width - 36 - width / 2))
    y = Math.max(0, (parentBounds.y + parentBounds.height) - height - 60)

    w = new BrowserWindow
      'node-integration': false,
      'web-preferences': {'web-security':false},
      'x': x
      'y': y
      'width': width,
      'height': height,
      'title': 'Feedback'

    {resourcePath} = atom.getLoadSettings()
    url = path.join(resourcePath, 'static', 'feedback.html')
    w.loadUrl("file://#{url}?#{params}")
    w.show()
