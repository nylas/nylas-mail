NylasStore = require 'nylas-store'
{Rx, Actions, DatabaseStore, ProviderSyncbackRequest, DeltaConnectionStatusStore} = require 'nylas-exports'
qs = require 'querystring'
_ = require 'underscore'
moment = require 'moment'

class DeveloperBarCurlRequest
  constructor: ({@id, request, statusCode, error}) ->
    url = request.url
    urlWithAuth = url
    if request.auth and (request.auth.user || request.auth.pass)
      urlWithAuth = url.replace('://', "://#{request.auth.user ? ""}:#{request.auth.pass ? ""}@")

    if request.qs
      url += "?#{qs.stringify(request.qs)}"
      urlWithAuth += "?#{qs.stringify(request.qs)}"

    postBody = ""
    postBody = JSON.stringify(request.body).replace(/'/g, '\\u0027') if request.body

    data = ""
    data = "-d '#{postBody}'" unless request.method == 'GET'

    headers = ""
    if request.headers
      for k,v of request.headers
        headers += "-H \"#{k}: #{v}\" "

    if request.auth?.bearer
      tok = request.auth.bearer.replace("!", "\\!")
      headers += "-H \"Authorization: Bearer #{tok}\" "

    baseCommand = "curl -X #{request.method} #{headers}#{data}"
    @command = baseCommand + " \"#{url}\""
    @commandWithAuth = baseCommand + " \"#{urlWithAuth}\""
    @statusCode = statusCode ? error?.code ? "pending"
    @errorMessage = error?.message ? error
    @startMoment = moment(request.startTime)
    @

class DeveloperBarStore extends NylasStore
  constructor: ->
    @_setStoreDefaults()
    @_registerListeners()

  ########### PUBLIC #####################################################

  curlHistory: -> @_curlHistory

  longPollStates: -> @_longPollStates

  longPollHistory: -> @_longPollHistory

  providerSyncbackRequests: -> @_providerSyncbackRequests

  ########### PRIVATE ####################################################

  triggerThrottled: ->
    @_triggerThrottled ?= _.throttle(@trigger, 150)
    @_triggerThrottled()

  _setStoreDefaults: ->
    @_curlHistoryIds = []
    @_curlHistory = []
    @_longPollHistory = []
    @_longPollStates = {}
    @_providerSyncbackRequests = []

  _registerListeners: ->
    query = DatabaseStore.findAll(ProviderSyncbackRequest)
      .order(ProviderSyncbackRequest.attributes.id.descending())
      .limit(100)
    Rx.Observable.fromQuery(query).subscribe(@_onSyncbackRequestChange)
    @listenTo DeltaConnectionStatusStore, @_onDeltaConnectionStatusChanged
    @listenTo Actions.willMakeAPIRequest, @_onWillMakeAPIRequest
    @listenTo Actions.didMakeAPIRequest, @_onDidMakeAPIRequest
    @listenTo Actions.longPollReceivedRawDeltas, @_onLongPollDeltas
    @listenTo Actions.longPollProcessedDeltas, @_onLongPollProcessedDeltas
    @listenTo Actions.clearDeveloperConsole, @_onClear

  _onClear: ->
    @_curlHistoryIds = []
    @_curlHistory = []
    @_longPollHistory = []
    @trigger(@)

  _onSyncbackRequestChange: (reqs = []) =>
    @_providerSyncbackRequests = reqs
    @trigger()

  _onDeltaConnectionStatusChanged: ->
    @_longPollStates = {}
    _.forEach DeltaConnectionStatusStore.getDeltaConnectionStates(), (state, accountId) =>
      @_longPollStates[accountId] = state.deltaStatus
    @trigger()

  _onLongPollDeltas: (deltas) ->
    # Add a local timestamp to deltas so we can display it
    now = new Date()
    delta.timestamp = now for delta in deltas

    # Incoming deltas are [oldest...newest]. Append them to the beginning
    # of our internal history which is [newest...oldest]
    @_longPollHistory.unshift([].concat(deltas).reverse()...)
    if @_longPollHistory.length > 200
      @_longPollHistory.length = 200
    @triggerThrottled(@)

  _onLongPollProcessedDeltas: ->
    @triggerThrottled(@)

  _onWillMakeAPIRequest: ({requestId, request}) =>
    item = new DeveloperBarCurlRequest({id: requestId, request})

    @_curlHistory.unshift(item)
    @_curlHistoryIds.unshift(requestId)
    if @_curlHistory.length > 200
      @_curlHistory.pop()
      @_curlHistoryIds.pop()

    @triggerThrottled(@)

  _onDidMakeAPIRequest: ({requestId, request, statusCode, error}) =>
    idx = @_curlHistoryIds.indexOf(requestId)
    return if idx is -1 # Could be more than 200 requests ago

    item = new DeveloperBarCurlRequest({id: requestId, request, statusCode, error})
    @_curlHistory[idx] = item
    @triggerThrottled(@)

module.exports = new DeveloperBarStore()
