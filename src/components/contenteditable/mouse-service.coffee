_ = require 'underscore'
{DOMUtils} = require 'nylas-exports'
ContenteditableService = require './contenteditable-service'

class MouseService extends ContenteditableService
  constructor: ->
    super
    @HOVER_DEBOUNCE = 250
    @setup()
    @timer = null
    @_inFrame = true

  eventHandlers: ->
    onClick: @_onClick
    onMouseEnter: (event) => @_inFrame = true
    onMouseLeave: (event) => @_inFrame = false
    onMouseOver: @_onMouseOver

  _onClick: (event) ->
    # We handle mouseDown, mouseMove, mouseUp, but we want to stop propagation
    # of `click` to make it clear that we've handled the event.
    # Note: Related to composer-view#_onClickComposeBody
    event.stopPropagation()

    ## NOTE: We can't use event.preventDefault() here for <a> tags because
    # the window-event-handler.coffee file has already caught the event.

  # We use global listeners to determine whether or not dragging is
  # happening. This is because dragging may stop outside the scope of
  # this element. Note that the `dragstart` and `dragend` events don't
  # detect text selection. They are for drag & drop.
  setup: ->
    window.addEventListener("mousedown", @_onMouseDown)
    window.addEventListener("mouseup", @_onMouseUp)

  teardown: ->
    window.removeEventListener("mousedown", @_onMouseDown)
    window.removeEventListener("mouseup", @_onMouseUp)

  _onMouseDown: (event) =>
    @_mouseDownEvent = event
    @_mouseHasMoved = false
    window.addEventListener("mousemove", @_onMouseMove)

    # We can't use the native double click event because that only fires
    # on the second up-stroke
    if Date.now() - (@_lastMouseDown ? 0) < 250
      @_onDoubleDown(event)
      @_lastMouseDown = 0 # to prevent triple down
    else
      @_lastMouseDown = Date.now()

  _onDoubleDown: (event) =>
    editable = @innerState.editableNode
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState doubleDown: true

  _onMouseMove: (event) =>
    if not @_mouseHasMoved
      @_onDragStart(@_mouseDownEvent)
      @_mouseHasMoved = true

  _onMouseUp: (event) =>
    window.removeEventListener("mousemove", @_onMouseMove)

    if @innerState.doubleDown
      @setInnerState doubleDown: false

    if @_mouseHasMoved
      @_mouseHasMoved = false
      @_onDragEnd(event)

    editableNode = @innerState.editableNode
    selection = document.getSelection()
    return event unless DOMUtils.selectionInScope(selection, editableNode)

    @dispatchEventToExtensions("onClick", event)
    return event

  _onDragStart: (event) =>
    editable = @innerState.editableNode
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState dragging: true

  _onDragEnd: (event) =>
    if @innerState.dragging
      @setInnerState dragging: false
    return event

  # Floating toolbar plugins need to know what we're currently hovering
  # over. We take care of debouncing the event handlers here to prevent
  # flooding plugins with events.
  _onMouseOver: (event) =>
    # @setInnerState hoveringOver: event.target

module.exports = MouseService
