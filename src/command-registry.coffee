{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{ipcRenderer} = require 'electron'

module.exports =
class CommandRegistry
  constructor: ->
    @emitter = new Emitter
    @listenerCounts = {}
    @listenerCountChanges = {}

  add: (target, commandName, callback) ->
    if typeof commandName is 'object'
      commands = commandName
      disposable = new CompositeDisposable
      for commandName, callback of commands
        disposable.add @add(target, commandName, callback)
      return disposable

    if typeof callback isnt 'function'
      throw new Error("Can't register a command with non-function callback.")

    if typeof target is 'string'
      throw new Error("Commands can no longer be registered to CSS selectors. Consider using KeyCommandRegion instead.")

    target.addEventListener(commandName, callback)
    @listenerCountChanges[commandName] = (@listenerCountChanges[commandName] || 0) + 1
    @flushChangesSoon()

    return new Disposable =>
      target.removeEventListener(commandName, callback)
      @listenerCountChanges[commandName] = (@listenerCountChanges[commandName] || 0) - 1
      @flushChangesSoon()

  listenerCountForCommand: (commandName) ->
    (@listenerCounts[commandName] || 0) + (@listenerCountChanges[commandName] || 0)

  # Public: Simulate the dispatch of a command on a DOM node.
  #
  # This can be useful for testing when you want to simulate the invocation of a
  # command on a detached DOM node. Otherwise, the DOM node in question needs to
  # be attached to the document so the event bubbles up to the root node to be
  # processed.
  #
  # * `target` The DOM node at which to start bubbling the command event.
  # * `commandName` {String} indicating the name of the command to dispatch.
  dispatch: (commandName, detail) ->
    event = new CustomEvent(commandName, {bubbles: true, detail})
    document.activeElement.dispatchEvent(event)

  flushChangesSoon: =>
    return if @pendingEmit
    @pendingEmit = true
    setTimeout =>
      @pendingEmit = false

      changed = false
      for commandName, val of @listenerCountChanges
        @listenerCounts[commandName] = (@listenerCounts[commandName] || 0) + val
        changed = true if val isnt 0
      @listenerCountChanges = {}
      if changed
        @emitter.emit('commands-changed')
    , 100

  onRegistedCommandsChanged: (callback) ->
    @emitter.on 'commands-changed', callback
