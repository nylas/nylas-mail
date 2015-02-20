Actions = require './actions'
Model = require './models/model'
{modelReviver} = require './models/utils'
DatabaseStore = require './stores/database-store'

Role =
  ROOT: 'root',
  SECONDARY: 'secondary'

TargetWindows =
  ALL: 'all',
  MAIN: 'main'

Message =
  DATABASE_STORE_TRIGGER: 'db-store-trigger'

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
    @ipc = ipc
    @initiatorId = atom.state.mode
    @role = if @initiatorId == 'editor' then Role.ROOT else Role.SECONDARY
    @logging = false

    # Listen for action bridge messages from other windows
    @ipc.on('action-bridge-message', @onIPCMessage)

    # Observe all global actions and re-broadcast them to other windows
    Actions.globalActions.forEach (name) =>
      callback = => @onRebroadcast(TargetWindows.ALL, name, arguments)
      Actions[name].listen(callback, @)

    if @role == Role.ROOT
      # Observe the database store (possibly other stores in the future), and
      # rebroadcast it's trigger() event.
      callback = (change) =>
        @onRebroadcast(TargetWindows.ALL, Message.DATABASE_STORE_TRIGGER, [change])
      DatabaseStore.listen(callback, @)

    else
      # Observe all mainWindow actions fired in this window and re-broadcast
      # them to other windows so the central application stores can take action
      Actions.mainWindowActions.forEach (name) =>
        callback = => @onRebroadcast(TargetWindows.MAIN, name, arguments)
        Actions[name].listen(callback, @)


  onIPCMessage: (initiatorId, name, json) =>
    console.log("#{@initiatorId} Action Bridge Received: #{name}") if @logging

    # Inflate the arguments using the modelReviver to get actual
    # Models, tasks, etc. out of the JSON
    try
      args = JSON.parse(json, modelReviver)
    catch e
      console.error(e)

    if name == Message.DATABASE_STORE_TRIGGER
      return unless @role == Role.SECONDARY
      DatabaseStore.trigger(args...)
    else if Actions[name]
      Actions[name].firing = true
      Actions[name](args...)
    else
      throw new Error("#{@initiatorId} received unknown action-bridge event: #{name}")


  onRebroadcast: (target, name, args...) =>
    if Actions[name]?.firing
      Actions[name].firing = false
      return

    params = []
    args.forEach (arg) ->
      if arg instanceof Function
        throw new Error("ActionBridge cannot forward action argument of type `function` to main window.")
      params.push(arg[0])
    json = JSON.stringify(params)

    console.log("#{@initiatorId} Action Bridge Broadcasting: #{name}") if @logging
    @ipc.send("action-bridge-rebroadcast-to-#{target}", @initiatorId, name, json)


module.exports = ActionBridge
