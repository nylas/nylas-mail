React = require 'react'
{Actions} = require("inbox-exports")
CalendarBarItem = require("./calendar-bar-item")
CalendarBarEventStore = require ("./calendar-bar-event-store")

class CalendarBarRow
  constructor: (initialItem = null) ->
    @items = []
    @last = 0
    if initialItem
      @last = initialItem.event.end
      @items.push(initialItem)
  
  canHoldItem: (item) ->
    item.event.start > @last

  addItem: (item) ->
    @last = item.event.end
    @items.push(item)

CalendarBarMarker = React.createClass
  render: ->
    classname = "marker"
    classname += " now" if @props.marker.now
    <div className={classname} style={left: @props.marker.xPercent} id={@props.marker.xPercent}/>

module.exports =
CalendarBar = React.createClass

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = CalendarBarEventStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    markers = @_getMarkers().map (marker) ->
      <CalendarBarMarker marker={marker}/>

    items = @_getItemsForEvents(@state.events)
    items = items.map (item) ->
      <CalendarBarItem item={item}/>

    <div className="calendar-bar-inner">
      {markers}
      {items}
    </div>

  _onStoreChange: ->
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    events: CalendarBarEventStore.events()
    range: CalendarBarEventStore.range()

  _getMarkers: ->
    range = @state.range
    now = (new Date).getTime()/1000 - range.start
    markers = []
    for hour in [0..24]
      time = 60*60*hour
      markers.push
        xPercent: (time * 100) / (range.end - range.start) + "%"
    markers.push
      now: true
      xPercent: (now * 100) / (range.end - range.start) + "%"
    markers

  _getItemsForEvents: (events) ->
    # Create an array of items with additional metadata needed for our view.
    # We compute the X and width of elements using their durations as a fraction
    # of the displayed range
    range = @state.range
    items = events.map (event) ->
      {
        event: event,
        z: event.start - range.start
        xPercent: (event.start - range.start) * 100 / (range.end - range.start) + "%",
        wPercent: (event.end - event.start) * 100 / (range.end - range.start) + "%"
      }

    # Compute the number of rows we need by assigning events to rows. This works by
    # creating virtual "row" objects which hold a series of non-overlapping events and
    # have a "last" timestamp. For each item, we iterate through the rows:
    #
    # - If the event fits in more than one row, we delete all but one of the rows.
    #   This ensures that if we have two overlapping events, the next event that
    #   does not overlap goes back to taking all of the available height. (Rows no
    #   longer necessary)
    #
    # - If the event does not fit in any rows, we create a new row, and tell all of
    #   the items in existing rows that they're now sharing space with a new row.

    rows = [new CalendarBarRow]
    for item in items
      for x in [rows.length-1..0] by -1
        if rows[x].canHoldItem(item)
          rows.splice(item.rowIndex, 1) unless item.rowIndex is undefined
          rows[x].addItem(item)
          item.rowIndex = x

      if item.rowIndex is undefined
        rows.push(new CalendarBarRow(item))
        item.rowIndex = rows.length - 1
        for row in rows
          for item in row.items
            item.rowCount += 1

      item.rowCount = rows.length

    # Now that each item knows what row it's in and how many rows are being displayed
    # alongside it, we can assign fractional positions to them.
    for item in items
      item.yPercent = (item.rowIndex / item.rowCount) * 100 + "%"
      item.hPercent = (100.0 / item.rowCount) + "%"

    items
