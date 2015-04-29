_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{FocusedContactsStore,
 NamespaceStore,
 PriorityUICoordinator} = require 'inbox-exports'

module.exports =
# The InternalAdminStore manages the data that backs the admin sidebar and emits
# a "trigger" event that the view listens to.
#
# If the Admin sidebar allowed you to take actions, like modifying someone's
# Nilas account, the InternalAdminStore would also listen for those user actions
# and perform business logic.
#
InternalAdminStore = Reflux.createStore

  init: ->
    @_accountCache = null
    @_applicationCache = null
    @_enabled = false
    @_error = null

    # Stores often listen to other stores to vend correct data to their views.
    # Since we serve information about a contact we listen for changes to the
    # focused contact. Since we only want to be enabled for @nilas.com emails,
    # we listen for changes to available Namespaces.
    @listenTo FocusedContactsStore, @_onFocusedContacts
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_onNamespaceChanged()


  dataForFocusedContact: ->
    return {loading: true} if @_accountCache is null or @_applicationCache is null
    contact = FocusedContactsStore.focusedContact()
    return {} unless contact

    account = _.find @_accountCache, (account) -> account.email is contact.email
    apps = undefined
    apps = @_applicationCache.accounts["#{account.id}"] if account

    # Coffeescript shorthand for {account: account, apps: apps}
    {account, apps}

  enabled: ->
    @_enabled

  error: ->
    @_error

  _onFocusedContacts: ->
    # When the user focuses on a contact, we don't need to do any work because we
    # cache everything. Just trigger so that our view updates and calls
    # `dataForFocusedContact`.
    @trigger(@)

  _onNamespaceChanged: ->
    clearInterval(@_fetchInterval) if @_fetchInterval
    @_fetchInterval = null

    # We only want to enable this package for users with nilas.com email addresses.
    n = NamespaceStore.current()
    if n and n.emailAddress.indexOf('@nylas.com') > 0
      @_fetchInterval = setInterval(( => @_fetchAPIData()), 5 * 60 * 1000)
      @_fetchAPIData()
      @_enabled = true
    else
      @_accountCache = null
      @_applicationCache = null
      @_enabled = false
    @trigger(@)

  _fetchAPIData: ->
    # Make a HTTP request to the Admin service using the `request` library. Using
    # the priority UI coordinator ensures that the expensive JSON.parse operation
    # doesn't happen while an animation is running.
    request 'https://admin.inboxapp.com/api/status/accounts', (err, resp, data) =>
      PriorityUICoordinator.settle.then =>
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

    request 'https://admin.inboxapp.com/api/status/accounts/applications', (err, resp, data) =>
      PriorityUICoordinator.settle.then =>
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
