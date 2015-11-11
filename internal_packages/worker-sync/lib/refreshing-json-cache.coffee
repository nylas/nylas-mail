_ = require 'underscore'
{NylasStore, DatabaseStore} = require 'nylas-exports'


class RefreshingJSONCache

  constructor: ({@key, @version, @refreshInterval}) ->
    @_timeoutId = null

  start: ->
    # Clear any scheduled actions
    @end()

    # Look up existing data from db
    DatabaseStore.findJSONObject(@key).then (json) =>

      # Refresh immediately if json is missing or version is outdated. Otherwise,
      # compute next refresh time and schedule
      timeUntilRefresh = 0
      if json? and json.version is @version
        timeUntilRefresh = Math.max(0, @refreshInterval - (Date.now() - json.time))

      @_timeoutId = setTimeout(@refresh, timeUntilRefresh)

  reset: ->
    # Clear db value, turn off any scheduled actions
    DatabaseStore.persistJSONObject(@key, {})
    @end()

  end: ->
    # Turn off any scheduled actions
    clearInterval(@_timeoutId) if @_timeoutId
    @_timeoutId = null

  refresh: =>
    # Set up next refresh call
    clearTimeout(@_timeoutId) if @_timeoutId
    @_timeoutId = setTimeout(@refresh, @refreshInterval)

    # Call fetch data function, save it to the database
    @fetchData (newValue) =>
      DatabaseStore.persistJSONObject(@key, {
        version: @version
        time: Date.now()
        value: newValue
      })

  fetchData: (callback) =>
    throw new Error("Subclasses should override this method.")



module.exports = RefreshingJSONCache
