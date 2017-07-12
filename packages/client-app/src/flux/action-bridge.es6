import _ from 'underscore';
import Actions from './actions';

import Utils from './models/utils';

const Role = {
  MAIN: 'default',
  SECONDARY: 'secondary',
};

const TargetWindows = {
  ALL: 'all',
  MAIN: 'default',
};

const printToConsole = false;

// Public: ActionBridge
//
//    When you're in a secondary window, the ActionBridge observes all Root actions. When a
//    Root action is fired, it converts it's payload to JSON, tunnels it to the main window
//    via IPC, and re-fires the Action in the main window. This means that calls to actions
//    like Actions.queueTask(task) can be fired in secondary windows and consumed by the
//    TaskQueue, which only lives in the main window.

class ActionBridge {
  static Role = Role;
  static TargetWindows = TargetWindows;

  constructor(ipc) {
    this.registerGlobalActions = this.registerGlobalActions.bind(this);
    this.onIPCMessage = this.onIPCMessage.bind(this);
    this.onRebroadcast = this.onRebroadcast.bind(this);
    this.onBeforeUnload = this.onBeforeUnload.bind(this);
    this.globalActions = [];
    this.ipc = ipc;
    this.ipcLastSendTime = null;
    this.initiatorId = NylasEnv.getWindowType();
    this.role = NylasEnv.isMainWindow() ? Role.MAIN : Role.SECONDARY;

    NylasEnv.onBeforeUnload(this.onBeforeUnload);

    // Listen for action bridge messages from other windows
    if (NylasEnv.isEmptyWindow()) {
      NylasEnv.onWindowPropsReceived(() => {
        this.ipc.on('action-bridge-message', this.onIPCMessage);
      });
    } else {
      this.ipc.on('action-bridge-message', this.onIPCMessage);
    }

    // Observe all global actions and re-broadcast them to other windows
    Actions.globalActions.forEach(name => {
      const callback = (...args) => this.onRebroadcast(TargetWindows.ALL, name, args);
      return Actions[name].listen(callback, this);
    });

    if (this.role !== Role.MAIN) {
      // Observe all mainWindow actions fired in this window and re-broadcast
      // them to other windows so the central application stores can take action
      Actions.mainWindowActions.forEach(name => {
        const callback = (...args) => this.onRebroadcast(TargetWindows.MAIN, name, args);
        return Actions[name].listen(callback, this);
      });
    }
  }

  registerGlobalActions({pluginName, actions}) {
    return _.each(actions, (actionFn, name) => {
      this.globalActions.push({name, actionFn, scope: pluginName});
      const callback = (...args) => {
        const broadcastName = `${pluginName}::${name}`;
        return this.onRebroadcast(TargetWindows.ALL, broadcastName, args);
      };
      return actionFn.listen(callback, this);
    }
    );
  }

  _isExtensionAction(name) {
    return name.split("::").length === 2;
  }

  _globalExtensionAction(broadcastName) {
    const [scope, name] = broadcastName.split("::");
    return (_.findWhere(this.globalActions, {scope, name}) || {}).actionFn
  }

  onIPCMessage(event, initiatorId, name, json) {
    if (NylasEnv.isEmptyWindow()) {
      throw new Error("Empty windows shouldn't receive IPC messages");
    }
    // There's something very strange about IPC event handlers. The ReactRemoteParent
    // threw React exceptions when calling setState from an IPC callback, and the debugger
    // often refuses to stop at breakpoints immediately inside IPC callbacks.

    // These issues go away when you add a setTimeout. So here's that.
    // I believe this resolves issues like https://sentry.nylas.com/sentry/edgehill/group/2735/,
    // which are React exceptions in a direct stack (no next ticks) from an IPC event.
    setTimeout(() => {
      console.debug(printToConsole, `ActionBridge: ${this.initiatorId} Action Bridge Received: ${name}`);

      const args = JSON.parse(json, Utils.modelTypesReviver);

      if (Actions[name]) {
        Actions[name].firing = true;
        Actions[name](...args);
      } else if (this._isExtensionAction(name)) {
        const fn = this._globalExtensionAction(name);
        if (fn) {
          fn.firing = true;
          fn(...args);
        }
      } else {
        throw new Error(`${this.initiatorId} received unknown action-bridge event: ${name}`);
      }
    }, 0);
  }

  onRebroadcast(target, name, args) {
    if (Actions[name] && Actions[name].firing) {
      Actions[name].firing = false;
      return;
    }

    const globalExtAction = this._globalExtensionAction(name);
    if (globalExtAction && globalExtAction.firing) {
      globalExtAction.firing = false;
      return;
    }

    const params = [];
    args.forEach((arg) => {
      if (arg instanceof Function) {
        throw new Error("ActionBridge cannot forward action argument of type `function` to another window.");
      }
      return params.push(arg);
    });

    const json = JSON.stringify(params, Utils.registeredObjectReplacer);

    console.debug(printToConsole, `ActionBridge: ${this.initiatorId} Action Bridge Broadcasting: ${name}`);
    this.ipc.send(`action-bridge-rebroadcast-to-${target}`, this.initiatorId, name, json);
    this.ipcLastSendTime = Date.now();
  }

  onBeforeUnload(readyToUnload) {
    // Unfortunately, if you call ipc.send and then immediately close the window,
    // Electron won't actually send the message. To work around this, we wait an
    // arbitrary amount of time before closing the window after the last IPC event
    // was sent. https://github.com/atom/electron/issues/4366
    if (this.ipcLastSendTime && Date.now() - this.ipcLastSendTime < 100) {
      setTimeout(readyToUnload, 100);
      return false;
    }
    return true;
  }
}

export default ActionBridge;
