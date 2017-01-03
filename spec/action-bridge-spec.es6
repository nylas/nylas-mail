import Actions from '../src/flux/actions';
import Message from '../src/flux/models/message';
import DatabaseStore from '../src/flux/stores/database-store';
import ActionBridge from '../src/flux/action-bridge';

const ipc = {
  on() {},
  send() {},
};

describe("ActionBridge", function actionBridge() {
  describe("in the work window", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "getWindowType").andReturn("default");
      spyOn(NylasEnv, "isWorkWindow").andReturn(true);
      this.bridge = new ActionBridge(ipc);
    });

    it("should have the role Role.WORK", () => {
      expect(this.bridge.role).toBe(ActionBridge.Role.WORK);
    });

    it("should rebroadcast global actions", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions[Actions.globalActions[0]];
      testAction('bla');
      expect(this.bridge.onRebroadcast).toHaveBeenCalled();
    });

    it("should rebroadcast when the DatabaseStore triggers", () => {
      spyOn(this.bridge, 'onRebroadcast');
      DatabaseStore.trigger({});
      expect(this.bridge.onRebroadcast).toHaveBeenCalled();
    });

    it("should not rebroadcast mainWindow actions since it is the main window", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions.didMakeAPIRequest;
      testAction('bla');
      expect(this.bridge.onRebroadcast).not.toHaveBeenCalled();
    });

    it("should not rebroadcast window actions", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions[Actions.windowActions[0]];
      testAction('bla');
      expect(this.bridge.onRebroadcast).not.toHaveBeenCalled();
    });
  });

  describe("in another window", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "getWindowType").andReturn("popout");
      spyOn(NylasEnv, "isWorkWindow").andReturn(false);
      this.bridge = new ActionBridge(ipc);
      this.message = new Message({
        id: 'test-id',
        accountId: TEST_ACCOUNT_ID,
      });
    });

    it("should have the role Role.SECONDARY", () => {
      expect(this.bridge.role).toBe(ActionBridge.Role.SECONDARY);
    });

    it("should rebroadcast global actions", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions[Actions.globalActions[0]];
      testAction('bla');
      expect(this.bridge.onRebroadcast).toHaveBeenCalled();
    });

    it("should rebroadcast mainWindow actions", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions.didMakeAPIRequest;
      testAction('bla');
      expect(this.bridge.onRebroadcast).toHaveBeenCalled();
    });

    it("should not rebroadcast window actions", () => {
      spyOn(this.bridge, 'onRebroadcast');
      const testAction = Actions[Actions.windowActions[0]];
      testAction('bla');
      expect(this.bridge.onRebroadcast).not.toHaveBeenCalled();
    });
  });

  describe("onRebroadcast", () => {
    beforeEach(() => {
      spyOn(NylasEnv, "getWindowType").andReturn("popout");
      spyOn(NylasEnv, "isMainWindow").andReturn(false);
      this.bridge = new ActionBridge(ipc);
    });

    describe("when called with TargetWindows.ALL", () => {
      it("should broadcast the action over IPC to all windows", () => {
        spyOn(ipc, 'send');
        Actions.didPassivelyReceiveNewModels.firing = false;
        this.bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didPassivelyReceiveNewModels', [{oldModel: '1', newModel: 2}]);
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-all', 'popout', 'didPassivelyReceiveNewModels', '[{"oldModel":"1","newModel":2}]');
      })
    });

    describe("when called with TargetWindows.WORK", () => {
      it("should broadcast the action over IPC to the main window only", () => {
        spyOn(ipc, 'send');
        Actions.didPassivelyReceiveNewModels.firing = false;
        this.bridge.onRebroadcast(ActionBridge.TargetWindows.WORK, 'didPassivelyReceiveNewModels', [{oldModel: '1', newModel: 2}]);
        expect(ipc.send).toHaveBeenCalledWith('action-bridge-rebroadcast-to-work', 'popout', 'didPassivelyReceiveNewModels', '[{"oldModel":"1","newModel":2}]');
      })
    });

    it("should not do anything if the current invocation of the Action was triggered by itself", () => {
      spyOn(ipc, 'send');
      Actions.didPassivelyReceiveNewModels.firing = true;
      this.bridge.onRebroadcast(ActionBridge.TargetWindows.ALL, 'didPassivelyReceiveNewModels', [{oldModel: '1', newModel: 2}]);
      expect(ipc.send).not.toHaveBeenCalled();
    });
  });
});
