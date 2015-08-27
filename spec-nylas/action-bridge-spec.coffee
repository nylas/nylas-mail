Reflux = require 'reflux'
Actions = require '../src/flux/actions'
Message = require '../src/flux/models/message'
DatabaseStore = require '../src/flux/stores/database-store'
AccountStore = require '../src/flux/stores/account-store'
ActionBridge = require '../src/flux/action-bridge',
_ = require 'underscore'

ipc =
    on: ->
    send: ->

describe "ActionBridge", ->

  describe "in the work window", ->
    beforeEach ->
      spyOn(atom, "getWindowType").andReturn "default"
      spyOn(atom, "isWorkWindow").andReturn true
      @bridge = new ActionBridge(ipc)

    it "should have the role Role.WORK", ->
      expect(@bridge.role).toBe(ActionBridge.Role.WORK)

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

  describe "in another window", ->
    beforeEach ->
      spyOn(atom, "getWindowType").andReturn "popout"
      spyOn(atom, "isWorkWindow").andReturn false
      @bridge = new ActionBridge(ipc)
      @message = new Message
        id: 'test-id'
        accountId: 'test-account-id'

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
      spyOn(atom, "getWindowType").andReturn "popout"
      spyOn(atom, "isMainWindow").andReturn false
      @bridge = new ActionBridge(ipc)

    describe "when called with TargetWindows.ALL", ->
      it "should broadcast the action over IPC to all windows", ->
        spyOn(ipc, 'send')
        Actions.didSwapModel.firing = false
        @bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didSwapModel', [{oldModel: '1', newModel: 2}])
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-all', 'popout', 'didSwapModel', '[{"oldModel":"1","newModel":2}]')

    describe "when called with TargetWindows.WORK", ->
      it "should broadcast the action over IPC to the main window only", ->
        spyOn(ipc, 'send')
        Actions.didSwapModel.firing = false
        @bridge.onRebroadcast(ActionBridge.TargetWindows.WORK, 'didSwapModel', [{oldModel: '1', newModel: 2}])
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-work', 'popout', 'didSwapModel', '[{"oldModel":"1","newModel":2}]')

    it "should not do anything if the current invocation of the Action was triggered by itself", ->
      spyOn(ipc, 'send')
      Actions.didSwapModel.firing = true
      @bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didSwapModel', [{oldModel: '1', newModel: 2}])
      expect(ipc.send).not.toHaveBeenCalled()
