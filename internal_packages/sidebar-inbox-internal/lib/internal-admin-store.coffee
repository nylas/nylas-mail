_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{FocusedContactsStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    @_accountCache = null
    @_applicationCache = null
    @listenTo FocusedContactsStore, @_onFocusedContacts

    setInterval(( => @_fetchAPIData()), 5 * 60 * 1000)
    @_fetchAPIData()

  dataForFocusedContact: ->
    return {loading: true} if @_accountCache is null or @_applicationCache is null
    contact = FocusedContactsStore.focusedContact()
    return {} unless contact
    account = _.find @_accountCache, (account) -> account.email is contact.email
    apps = undefined
    if account
      apps = @_applicationCache.accounts["#{account.id}"]
    {account, apps}

  _onFocusedContacts: ->
    @trigger(@)

  _fetchAPIData: ->
    console.log('Fetching Internal Admin Data')
    # Swap the url's to see real data
    request 'https://admin.inboxapp.com/api/status/accounts', (err, resp, data) =>
      console.log(err) if err
      @_accountCache = JSON.parse(data)
      @trigger(@)

    # Swap the url's to see real data
    request 'https://admin.inboxapp.com/api/status/accounts/applications', (err, resp, data) =>
      console.log(err) if err
      @_applicationCache = JSON.parse(data)
      @trigger(@)