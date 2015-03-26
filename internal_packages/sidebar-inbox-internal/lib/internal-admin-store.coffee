_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{FocusedContactsStore, NamespaceStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    @_accountCache = null
    @_applicationCache = null
    @_enabled = false
    @_error = null

    @listenTo FocusedContactsStore, @_onFocusedContacts
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_onNamespaceChanged()

  dataForFocusedContact: ->
    return {loading: true} if @_accountCache is null or @_applicationCache is null
    contact = FocusedContactsStore.focusedContact()
    return {} unless contact
    account = _.find @_accountCache, (account) -> account.email is contact.email
    apps = undefined
    if account
      apps = @_applicationCache.accounts["#{account.id}"]
    {account, apps}

  enabled: ->
    @_enabled

  error: ->
    @_error

  _onFocusedContacts: ->
    @trigger(@)

  _onNamespaceChanged: ->
    clearInterval(@_fetchInterval) if @_fetchInterval
    @_fetchInterval = null

    n = NamespaceStore.current()
    if n and n.emailAddress.indexOf('@nilas.com') > 0
      @_fetchInterval = setInterval(( => @_fetchAPIData()), 5 * 60 * 1000)
      @_fetchAPIData()
      @_enabled = true
    else
      @_accountCache = null
      @_applicationCache = null
      @_enabled = false
    @trigger(@)

  _fetchAPIData: ->
    console.log('Fetching Internal Admin Data')
    # Swap the url's to see real data
    request 'https://admin.inboxapp.com/api/status/accounts', (err, resp, data) =>
      if err
        @_error = err
      else
        @_error = null
        try
          @_accountCache = JSON.parse(data)
        catch err
          @_error = err
          @_accountCache = null
      @trigger(@)

    # Swap the url's to see real data
    request 'https://admin.inboxapp.com/api/status/accounts/applications', (err, resp, data) =>
      if err
        @_error = err
      else
        @_error = null
        try
          @_applicationCache = JSON.parse(data)
        catch err
          @_error = err
          @_applicationCache = null
      @trigger(@)