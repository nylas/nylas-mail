_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{FocusedContactsStore} = require 'nylas-exports'

module.exports =

# This package uses the Flux pattern - our Store is a small singleton that
# observes other parts of the application and vends data to our React
# component. If the user could interact with the GithubSidebar, this store
# would also listen for `Actions` emitted by our React components.
GithubUserStore = Reflux.createStore

  init: ->
    @_profile = null
    @_cache = {}
    @_loading = false
    @_error = null

    # Register a callback with the FocusedContactsStore. This will tell us
    # whenever the selected person has changed so we can refresh our data.
    @listenTo FocusedContactsStore, @_onFocusedContactChanged

  # Getter Methods

  profileForFocusedContact: ->
    @_profile

  loading: ->
    @_loading

  error: ->
    @_error

  # Called when the FocusedContactStore `triggers`, notifying us that the data
  # it vends has changed.
  _onFocusedContactChanged: ->
    # Grab the new focused contact
    contact = FocusedContactsStore.focusedContact()

    # First, clear the contact that we're currently showing and `trigger`. Since
    # our React component observes our store, `trigger` causes our React component
    # to re-render.
    @_error = null
    @_profile = null

    if contact
      @_profile = @_cache[contact.email]
      # Make a Github search request to find the matching user profile
      @_githubFetchProfile(contact.email) unless @_profile?

    @trigger(@)

  _githubFetchProfile: (email) ->
    @_loading = true
    @_githubRequest "https://api.github.com/search/users?q=#{email}", (err, resp, data) =>
      console.warn(data.message) if data.message?

      # Sometimes we get rate limit errors, etc., so we need to check and make
      # sure we've gotten items before pulling the first one.
      profile = data?.items?[0] ? false

      # If a profile was found, make a second request for the user's public
      # repositories.
      if profile
        profile.repos = []
        @_githubRequest profile.repos_url, (err, resp, repos) =>
          # Sort the repositories by their stars (`-` for descending order)
          profile.repos = _.sortBy repos, (repo) -> -repo.stargazers_count
          # Trigger so that our React components refresh their state and display
          # the updated data.
          @trigger(@)

      @_loading = false
      @_profile = @_cache[email] = profile
      @trigger(@)

   # Wrap the Node `request` library and pass the User-Agent header, which is required
   # by Github's API. Also pass `json:true`, which causes responses to be automatically
   # parsed.
   _githubRequest: (url, callback) ->
      request({url: url, headers: {'User-Agent': 'request'}, json: true}, callback)
