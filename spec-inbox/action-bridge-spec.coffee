Reflux = require 'reflux'
Actions = require '../src/flux/actions'
ActionBridge = require '../src/flux/action-bridge'
Message = require '../src/flux/models/message'
DatabaseStore = require '../src/flux/stores/database-store'
NamespaceStore = require '../src/flux/stores/namespace-store'
_ = require 'underscore-plus'

ipc =
    on: ->
    send: ->

describe "ActionBridge", ->

  describe "in the editor window", ->
    beforeEach ->
      atom.state.mode = 'editor'
      @bridge = new ActionBridge(ipc)

    it "should have the role Role.ROOT", ->
      expect(@bridge.role).toBe(ActionBridge.Role.ROOT)

    it "should rebroadcast global actions", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions[Actions.globalActions[0]]
      testAction('bla')
      expect(@bridge.onRebroadcast).toHaveBeenCalled()

    it "should rebroadcast when the DatabaseStore triggers", ->
      spyOn(@bridge, 'onRebroadcast')
      DatabaseStore.trigger({})
      expect(@bridge.onRebroadcast).toHaveBeenCalled()

    it "should not rebroadcast mainWindow actions since it is the main window", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions.didMakeAPIRequest
      testAction('bla')
      expect(@bridge.onRebroadcast).not.toHaveBeenCalled()

    it "should not rebroadcast window actions", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions[Actions.windowActions[0]]
      testAction('bla')
      expect(@bridge.onRebroadcast).not.toHaveBeenCalled()

  describe "in a secondary window", ->
    beforeEach ->
      atom.state.mode = 'composer'
      @bridge = new ActionBridge(ipc)
      @message = new Message
        id: 'test-id'
        namespaceId: 'test-namespace-id'

    it "should have the role Role.SECONDARY", ->
      expect(@bridge.role).toBe(ActionBridge.Role.SECONDARY)

    it "should rebroadcast global actions", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions[Actions.globalActions[0]]
      testAction('bla')
      expect(@bridge.onRebroadcast).toHaveBeenCalled()

    it "should rebroadcast mainWindow actions", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions.didMakeAPIRequest
      testAction('bla')
      expect(@bridge.onRebroadcast).toHaveBeenCalled()

    it "should not rebroadcast window actions", ->
      spyOn(@bridge, 'onRebroadcast')
      testAction = Actions[Actions.windowActions[0]]
      testAction('bla')
      expect(@bridge.onRebroadcast).not.toHaveBeenCalled()

  describe "onRebroadcast", ->
    beforeEach ->
      atom.state.mode = 'composer'
      @bridge = new ActionBridge(ipc)
    
    describe "when called with TargetWindows.ALL", ->
      it "should broadcast the action over IPC to all windows", ->
        spyOn(ipc, 'send')
        Actions.didSwapModel.firing = false
        @bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didSwapModel', [{oldModel: '1', newModel: 2}])
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-all', 'composer', 'didSwapModel', '[{"oldModel":"1","newModel":2}]')
    
    describe "when called with TargetWindows.MAIN", ->
      it "should broadcast the action over IPC to the main window only", ->
        spyOn(ipc, 'send')
        Actions.didSwapModel.firing = false
        @bridge.onRebroadcast(ActionBridge.TargetWindows.MAIN, 'didSwapModel', [{oldModel: '1', newModel: 2}])
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-main', 'composer', 'didSwapModel', '[{"oldModel":"1","newModel":2}]')
    
    it "should not do anything if the current invocation of the Action was triggered by itself", ->
      spyOn(ipc, 'send')
      Actions.didSwapModel.firing = true
      @bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didSwapModel', [{oldModel: '1', newModel: 2}])
      expect(ipc.send).not.toHaveBeenCalled()

