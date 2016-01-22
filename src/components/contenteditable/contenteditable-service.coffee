# These are additions to the Contenteditable component that are tightly
# coupled to the props, state, and innerState of the parent component.
#
# They're designed to better separate concerns of the Contenteditable
class ContenteditableService
  constructor: ({@data, @methods}) ->
    {@props, @state, @innerState} = @data
    {@setInnerState, @dispatchEventToExtensions} = @methods

  setData: ({@props, @state, @innerState}) ->

  eventHandlers: -> {}

  teardown: -> # OVERRIDE ME

module.exports = ContenteditableService
