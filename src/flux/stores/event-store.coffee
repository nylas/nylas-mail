Reflux = require 'reflux'
Actions = require '../actions'
Event = require '../models/event'
Utils = require '../models/utils'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore'

EventRSVPTask = require '../tasks/event-rsvp'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

###
Public: EventStore maintains

## Listening for Changes

The EventStore monitors the {DatabaseStore} for changes to {Event} models
and triggers when events have changed, allowing your stores and components
to refresh data based on the EventStore.

```coffee
@unsubscribe = EventStore.listen(@_onEventsChanged, @)

_onEventsChanged: ->
  # refresh your event results
```

Section: Stores
###
class EventStore extends NylasStore

  constructor: ->
    @_eventCache = {}
    @_namespaceId = null
    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    # From Views
    @listenTo Actions.RSVPEvent, @_onRSVPEvent

    @__refreshCache()

  _onRSVPEvent: (calendar_event, RSVPStatus) ->
    task = new EventRSVPTask(calendar_event, RSVPStatus)
    Actions.queueTask(task)

  __refreshCache: =>
    new Promise (resolve, reject) =>
      DatabaseStore.findAll(Event)
      .then (events=[]) =>
        @_eventCache[e.id] = e for e in events
        @trigger()
        resolve()
      .catch (err) ->
        console.warn("Request for Events failed. #{err}")
  _refreshCache: _.debounce(EventStore::__refreshCache, 20)

  _onDatabaseChanged: (change) =>
    return unless change?.objectClass is Event.name
    for e in change.objects
      @_eventCache[e.id] = e

  _resetCache: =>
    @_eventCache = {}
    @trigger(@)

  getEvent: (id) =>
    @_eventCache[id]

  _onNamespaceChanged: =>
    return if @_namespaceId is NamespaceStore.current()?.id
    @_namespaceId = NamespaceStore.current()?.id

    if @_namespaceId
      @_refreshCache()
    else
      @_resetCache()

module.exports = new EventStore()
