_ = require 'underscore'
Actions = require './actions'
Model = require './models/model'
DatabaseStore = require './stores/database-store'

Utils = require './models/utils'

Role =
  WORK: 'work',
  SECONDARY: 'secondary'

TargetWindows =
  ALL: 'all',
  WORK: 'work'

Message =
  DATABASE_STORE_TRIGGER: 'db-store-trigger'

printToConsole = false

# Public: ActionBridge
#
# The ActionBridge has two responsibilities:
# 1. When you're in a secondary window, the ActionBridge observes all Root actions. When a
#    Root action is fired, it converts it's payload to JSON, tunnels it to the main window
#    via IPC, and re-fires the Action in the main window. This means that calls to actions
#    like Actions.queueTask(task) can be fired in secondary windows and consumed by the
#    TaskQueue, which only lives in the main window.

# 2. The ActionBridge listens to the DatabaseStore and re-broadcasts it's trigger() event
#    into all of the windows of the application. This is important, because the DatabaseStore
#    in all secondary windows is a read-replica. Only the DatabaseStore in the main window
#    of the application consumes persistModel actions and writes changes to the database.

class ActionBridge
  @Role: Role
  @Message: Message
  @TargetWindows: TargetWindows

  constructor: (ipc) ->
    @globalActions = []
    @ipc = ipc
    @ipcLastSendTime = null
    @initiatorId = NylasEnv.getWindowType()
    @role = if NylasEnv.isWorkWindow() then Role.WORK else Role.SECONDARY

    NylasEnv.onBeforeUnload(@onBeforeUnload)

    # Listen for action bridge messages from other windows
    @ipc.on('action-bridge-message', @onIPCMessage)

    # Observe all global actions and re-broadcast them to other windows
    Actions.globalActions.forEach (name) =>
      callback = (args...) => @onRebroadcast(TargetWindows.ALL, name, args)
      Actions[name].listen(callback, @)

    # Observe the database store (possibly other stores in the future), and
    # rebroadcast it's trigger() event.
    databaseCallback = (change) =>
      return if DatabaseStore.triggeringFromActionBridge
      @onRebroadcast(TargetWindows.ALL, Message.DATABASE_STORE_TRIGGER, [change])
    DatabaseStore.listen(databaseCallback, @)

    if @role isnt Role.WORK
      # Observe all mainWindow actions fired in this window and re-broadcast
      # them to other windows so the central application stores can take action
      Actions.workWindowActions.forEach (name) =>
        callback = (args...) => @onRebroadcast(TargetWindows.WORK, name, args)
        Actions[name].listen(callback, @)

  registerGlobalAction: ({scope, name, actionFn}) =>
    @globalActions.push({scope, name, actionFn})
    callback = (args...) =>
      broadcastName = "#{scope}::#{name}"
      @onRebroadcast(TargetWindows.ALL, broadcastName, args)
    actionFn.listen(callback, @)

  _isExtensionAction: (name) ->
    name.split("::").length is 2

  _globalExtensionAction: (broadcastName) ->
    [scope, name] = broadcastName.split("::")
    {actionFn} = _.findWhere(@globalActions, {scope, name}) ? {}
    return actionFn

  onIPCMessage: (event, initiatorId, name, json) =>
    # There's something very strange about IPC event handlers. The ReactRemoteParent
    # threw React exceptions when calling setState from an IPC callback, and the debugger
    # often refuses to stop at breakpoints immediately inside IPC callbacks.

    # These issues go away when you add a process.nextTick. So here's that.
    # I believe this resolves issues like https://sentry.nylas.com/sentry/edgehill/group/2735/,
    # which are React exceptions in a direct stack (no next ticks) from an IPC event.
    process.nextTick =>
      console.debug(printToConsole, "ActionBridge: #{@initiatorId} Action Bridge Received: #{name}")

      args = JSON.parse(json, Utils.registeredObjectReviver)

      if name == Message.DATABASE_STORE_TRIGGER
        DatabaseStore.triggeringFromActionBridge = true
        DatabaseStore.trigger(new DatabaseStore.ChangeRecord(args...))
        DatabaseStore.triggeringFromActionBridge = false

      else if Actions[name]
        Actions[name].firing = true
        Actions[name](args...)
      else if @_isExtensionAction(name)
        fn = @_globalExtensionAction(name)
        if fn
          fn.firing = true
          fn(args...)
      else
        throw new Error("#{@initiatorId} received unknown action-bridge event: #{name}")

  onRebroadcast: (target, name, args) =>
    if Actions[name]?.firing
      Actions[name].firing = false
      return
    else if @_globalExtensionAction(name)?.firing
      @_globalExtensionAction(name).firing = false
      return

    params = []
    args.forEach (arg) ->
      if arg instanceof Function
        throw new Error("ActionBridge cannot forward action argument of type `function` to work window.")
      params.push(arg)

    json = JSON.stringify(params, Utils.registeredObjectReplacer)

    console.debug(printToConsole, "ActionBridge: #{@initiatorId} Action Bridge Broadcasting: #{name}")
    @ipc.send("action-bridge-rebroadcast-to-#{target}", @initiatorId, name, json)
    @ipcLastSendTime = Date.now()

  onBeforeUnload: (readyToUnload) =>
    # Unfortunately, if you call ipc.send and then immediately close the window,
    # Electron won't actually send the message. To work around this, we wait an
    # arbitrary amount of time before closing the window after the last IPC event
    # was sent. https://github.com/atom/electron/issues/4366
    if @ipcLastSendTime and Date.now() - @ipcLastSendTime < 50
      setTimeout(readyToUnload, 50)
      return false
    return true

module.exports = ActionBridge
