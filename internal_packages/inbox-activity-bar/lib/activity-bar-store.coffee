Reflux = require 'reflux'
{Actions} = require 'inbox-exports'
qs = require 'querystring'

ActivityBarStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()


  ########### PUBLIC #####################################################

  curlHistory: -> @_curlHistory

  expandedSection: -> @_section

  longPollState: -> @_longPollState

  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_curlHistory = []
    @_minified = true
    @_longPollState = 'Unknown'

  _registerListeners: ->
    @listenTo Actions.didMakeAPIRequest, @_onAPIRequest
    @listenTo Actions.developerPanelSelectSection, @_onSelectSection
    @listenTo Actions.longPollStateChanged, @_onLongPollStateChange
    @listenTo Actions.logout, @_onLogout

  _onLogout: ->
    @_setStoreDefaults()
    @trigger(@)

  _onSelectSection: (section) ->
    @_section = section
    @trigger(@)

  _onLongPollStateChange: (state) ->
    @_longPollState = state
    @trigger(@)

  _onAPIRequest: ({request, response}) ->
    url = request.url
    if request.auth
      url = url.replace('://', "://#{request.auth.user}:#{request.auth.pass}@")
    if request.qs
      url += "?#{qs.stringify(request.qs)}"
    postBody = ""
    postBody = JSON.stringify(request.body).replace(/'/g, '\\u0027') if request.body
    data = ""
    data = "-d '#{postBody}'" unless request.method == 'GET'

    item =
      command: "curl -X #{request.method} #{data} #{url}"
      statusCode: response?.statusCode || 0
    @_curlHistory.unshift(item)
    @trigger(@)

module.exports = ActivityBarStore
