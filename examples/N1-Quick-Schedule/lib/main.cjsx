# # QuickSchedule
#
# A fairly complex package which allows you to select calendar availabilities
# to email. Whoever receives your email with your availabilities can click on
# your availabilities to schedule an appointment with you.

{ComponentRegistry,
 DatabaseStore,
 DraftStore,
 QuotedHTMLParser,
 ExtensionRegistry,
 Event} = require 'nylas-exports'

url = require('url')
qs = require("querystring")

CalendarButton = require './calendar-button'
AvailabilityComposerExtension = require './availability-composer-extension'

protocol = require('remote').require('protocol')

# A simple class for building HTML in code
class HtmlNode
  constructor: (name) ->
    @name = name
    @attrs = {}
    @styles = {}
    @children = []

  attr: (k,v,isJson=false) ->
    @attrs[k] = if isJson then btoa(v) else v
    return @

  style: (k,v) ->
    @styles[k] = v
    return @

  append: (node) ->
    @children.push(node)
    return node

  appendNode: (name) ->
    node = new HtmlNode(name)
    return @append(node)

  appendText: (text) ->
    @append(text)
    return @

  toString: ->
    attrs = ("#{k}=\"#{v}\"" for k,v of @attrs).join(" ")
    styles = ("#{k}: #{v};" for k,v of @styles).join(" ")

    if @children?.length > 0
      children = (if n instanceof HtmlNode then n.toString() else n for n in @children).join("\n")
      return "<#{@name} #{attrs} style=\"#{styles}\">\n#{children}\n</#{@name}>"
    else
      return "<#{@name} #{attrs} style=\"#{styles}\" />"


module.exports =

  ### Package Methods ###

  # Activate is called when the package is loaded. If your package previously
  # saved state using `serialize` it is provided.
  #
  activate: (@state) ->
    # Using `ComponentRegistry.register`, we insert an instance of
    # `CalendarButton` into the `'Composer:ActionButton'` section of the
    # application, to sit along with the other React components already inside
    # `'Composer:ActionButton'`.
    ComponentRegistry.register CalendarButton,
      role: 'Composer:ActionButton'

    # You can add your own extensions to the N1 Composer view and the original
    # Composer by invoking `ExtensionRegistry.Composer.register` with a subclass of
    # `ComposerExtension`.
    ExtensionRegistry.Composer.register AvailabilityComposerExtension

    # Register a protocol that allows the calendar window to pass data back to the plugin
    # with web requests
    if NylasEnv.isMainWindow()
      # First unregister the protocol, in case it has already been registered with a callback that's no
      # longer valid (e.g. if the main window has reloaded). If the protocol is not registered, this line
      # does nothing.
      protocol.unregisterProtocol('quick-schedule')
      # Now register the new protocol
      protocol.registerStringProtocol 'quick-schedule', (request, callback) =>
        {host:event,query:rawQuery} = url.parse(request.url)
        stringArgs = qs.parse(rawQuery)
        data = {}
        for own k,v of stringArgs
          data[k] = JSON.parse(v)
        response = @_onCalendarEvent(event,data,callback)

  # Serialize is called when your package is about to be unmounted.
  # You can return a state object that will be passed back to your package
  # when it is re-activated.
  #
  serialize: ->

  # This **optional** method is called when the window is shutting down,
  # or when your package is being updated or disabled. If your package is
  # watching any files, holding external resources, providing commands or
  # subscribing to events, release them here.
  #
  deactivate: ->
    ComponentRegistry.unregister CalendarButton
    ExtensionRegistry.Composer.unregister AvailabilityComposerExtension
    if NylasEnv.isMainWindow()
      protocol.unregisterProtocol('quick-schedule')

  ### Internal Methods ###

  _onCalendarEvent: (event,data,callback) ->
    switch event
      when "get_events"
        {start,end,id:eventId} = data
        DatabaseStore.findAll(Event).where([
          Event.attributes.start.lessThan(end),
          Event.attributes.end.greaterThan(start),
        ]).then (events) =>
          callback(JSON.stringify(events))
      when "available_times"
        {draftClientId,eventData,events} = data.data
        @_addBlockToDraft(events,draftClientId,eventData)

  # Grabs the current draft text, appends the quick-schedule HTML block to it, and saves
  _addBlockToDraft: (events,draftClientId,eventData) ->
    # Obtain the session for the current draft.
    DraftStore.sessionForClientId(draftClientId).then (session) =>
      draftHtml = session.draft().body
      text = QuotedHTMLParser.removeQuotedHTML(draftHtml)

      # add the block
      text += "<br/>"+@_createBlock(events,eventData)+"<br/>"

      newDraftHtml = QuotedHTMLParser.appendQuotedHTML(text, draftHtml)

      # update the draft
      session.changes.add(body: newDraftHtml)
      session.changes.commit()

  # Given the data for an event and its availability slots, creates an HTML string
  # that can be inserted into an email message
  _createBlock: (events,eventData) ->
    # Group the events by their `date`, to give one box per day
    byDay = {}
    for event in events
      (byDay[event.date] ?= []).push(event)

    # Create an HtmlNode and write its attributes and child nodes
    block = new HtmlNode("div")
      .attr("class","quick-schedule")
      .attr("data-quick-schedule",JSON.stringify({
        # add the full event data here as JSON so that it can be read by this plugin
        # elsewhere (e.g. right before sending the draft, etc)
        event: eventData
        times: ({start,end,serverKey} = e for e in events)
      }), true)
      .style("border","1px solid #EEE")
      .style("border-radius","3px")
      .style("padding","10px")

    eventInfo = block.appendNode("div")
      .attr("class","event-container")
      .style("padding","0 5px")

    eventInfo.appendNode("div")
      .attr("class","event-title")
      .appendText(eventData.title)
      .style("font-weight","bold")
      .style("font-size","18px")
    eventInfo.appendNode("div")
      .attr("class","event-location")
      .appendText(eventData.location)
    eventInfo.appendNode("div")
      .attr("class","event-description")
      .style("font-size","13px")
      .appendText(eventData.description)
    eventInfo.appendNode("span")
      .appendText("Click on a time to schedule instantly:")
      .style("font-size","13px")
      .style("color","#AAA")

    daysContainer = block.appendNode("div")
      .attr("class","days")
      .style("display","flex")
      .style("flex-wrap","wrap")
      .style("padding","10px 0")

    # Create one div per day, and write each time slot in as a line
    for dayText,dayEvents of byDay
      dayBlock = daysContainer.appendNode("div")
        .attr("class","day-container")
        .style("flex-grow","1")
        .style("margin","5px")
        .style("border","1px solid #DDD")
        .style("border-radius","3px")

      dayBlock.appendNode("div")
        .attr("class","day-title")
        .style("text-align","center")
        .style("font-size","13px")
        .style("background","#EEE")
        .style("color","#666")
        .style("padding","2px 4px")
        .appendText(dayText.toUpperCase())

      times = dayBlock.appendNode("div")
        .attr("class","day-times")
        .style("padding","5px")

      # One line per time slot
      for e in dayEvents
        # The URL points to the event page with this time slot selected
        eventUrl = url.format({
          protocol: "https"
          host: "quickschedule.herokuapp.com"
          pathname: "/event/#{e.serverKey}"
        })
        times.appendNode("div")
          .attr("class","day-time")
          .style("padding","2px 0")
          .appendNode("a")
            .attr("href",eventUrl)
            .attr("data-starttime",e.start)
            .attr("data-endtime",e.end)
            .style("text-decoration","none")
            .appendText(e.time)

    return block.toString()
