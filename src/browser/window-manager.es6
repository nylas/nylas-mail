import _ from 'underscore';
import WindowLauncher from './window-launcher';
import {app} from 'electron';

const MAIN_WINDOW = "default"
const WORK_WINDOW = "work"
const SPEC_WINDOW = "spec"
const ONBOARDING_WINDOW = "onboarding"

export default class WindowManager {

  constructor({devMode, safeMode, resourcePath, configDirPath, initializeInBackground, config}) {
    this.initializeInBackground = initializeInBackground;
    this._windows = {};

    const onCreatedHotWindow = (win) => {
      this._registerWindow(win);
      this._didCreateNewWindow(win);
    }
    this.windowLauncher = new WindowLauncher({devMode, safeMode, resourcePath, configDirPath, config, onCreatedHotWindow});
  }

  get(windowKey) {
    return this._windows[windowKey];
  }

  getOpenWindows() {
    const values = [];
    Object.keys(this._windows).forEach((key) => {
      const win = this._windows[key];
      if (win.windowType !== WindowLauncher.EMPTY_WINDOW) {
        values.push(win);
      }
    });

    const score = (win) =>
      (win.loadSettings().mainWindow ? 1000 : win.browserWindow.id);

    return values.sort((a, b) => score(b) - score(a));
  }

  newWindow(options = {}) {
    const win = this.windowLauncher.newWindow(options);
    const existingKey = this._registeredKeyForWindow(win);

    if (existingKey) {
      delete this._windows[existingKey];
    }
    this._registerWindow(win);

    if (!existingKey) {
      this._didCreateNewWindow(win);
    }

    return win;
  }

  _registerWindow = (win) => {
    if (!win.windowKey) {
      throw new Error("WindowManager: You must provide a windowKey");
    }

    if (this._windows[win.windowKey]) {
      throw new Error(`WindowManager: Attempting to register a new window for an existing windowKey (${win.windowKey}). Use 'get()' to retrieve the existing window instead.`);
    }

    this._windows[win.windowKey] = win;
  }

  _didCreateNewWindow = (win) => {
    win.browserWindow.on("closed", () => {
      delete this._windows[win.windowKey];
      this.quitWinLinuxIfNoWindows();
    });

    // Let the applicationMenu know that there's a new window available.
    // The applicationMenu automatically listens to the `closed` event of
    // the browserWindow to unregister itself
    global.application.applicationMenu.addWindow(win.browserWindow);
  }

  _registeredKeyForWindow = (win) => {
    for (const key of Object.keys(this._windows)) {
      const otherWin = this._windows[key];
      if (win === otherWin) {
        return key;
      }
    }
    return null;
  }

  ensureWindow(windowKey, extraOpts) {
    const win = this._windows[windowKey];

    if (!win) {
      this.newWindow(this._coreWindowOpts(windowKey, extraOpts));
      return;
    }

    if (win.loadSettings().hidden) {
      return;
    }

    if (win.isMinimized()) {
      win.restore();
      win.focus();
    } else if (!win.isVisible()) {
      win.showWhenLoaded();
    } else {
      win.focus();
    }
  }

  sendToAllWindows(msg, {except}, ...args) {
    for (const windowKey of Object.keys(this._windows)) {
      const win = this._windows[windowKey];
      if (win.browserWindow === except) {
        continue;
      }
      if (!win.browserWindow.webContents) {
        continue;
      }
      win.browserWindow.webContents.send(msg, ...args);
    }
  }

  destroyAllWindows() {
    this.windowLauncher.cleanupBeforeAppQuit();
    for (const windowKey of Object.keys(this._windows)) {
      this._windows[windowKey].browserWindow.destroy();
    }
    this._windows = {}
  }

  cleanupBeforeAppQuit() {
    this.windowLauncher.cleanupBeforeAppQuit();
  }

  quitWinLinuxIfNoWindows() {
    // Typically, N1 stays running in the background on all platforms, since it
    // has a status icon you can use to quit it.

    // However, on Windows and Linux we /do/ want to quit if the app is somehow
    // put into a state where there are no visible windows and the main window
    // doesn't exist.

    // This /shouldn't/ happen, but if it does, the only way for them to recover
    // would be to pull up the Task Manager. Ew.

    if (['win32', 'linux'].includes(process.platform)) {
      this.quitCheck = this.quitCheck || _.debounce(() => {
        const visibleWindows = _.filter(this._windows, (win) => win.isVisible())
        const mainWindow = this.get(WindowManager.MAIN_WINDOW);
        const noMainWindowLoaded = !mainWindow || !mainWindow.isLoaded();
        if (visibleWindows.length === 0 && noMainWindowLoaded) {
          app.quit();
        }
      }, 25000);
      this.quitCheck();
    }
  }

  focusedWindow() {
    return _.find(this._windows, (win) => win.isFocused());
  }

  _coreWindowOpts(windowKey, extraOpts = {}) {
    const coreWinOpts = {}
    coreWinOpts[WindowManager.MAIN_WINDOW] = {
      windowKey: WindowManager.MAIN_WINDOW,
      windowType: WindowManager.MAIN_WINDOW,
      title: "Message Viewer",
      neverClose: true,
      bootstrapScript: require.resolve("../window-bootstrap"),
      mainWindow: true,
      width: 640, // Gets reset once app boots up
      height: 396, // Gets reset once app boots up
      center: true, // Gets reset once app boots up
      resizable: false, // Gets reset once app boots up
      initializeInBackground: this.initializeInBackground,
    };

    coreWinOpts[WindowManager.WORK_WINDOW] = {
      windowKey: WindowManager.WORK_WINDOW,
      windowType: WindowManager.WORK_WINDOW,
      coldStartOnly: true, // It's a secondary window, but not a hot window
      title: "Activity",
      hidden: true,
      neverClose: true,
      width: 800,
      height: 400,
    }

    coreWinOpts[WindowManager.ONBOARDING_WINDOW] = {
      windowKey: WindowManager.ONBOARDING_WINDOW,
      windowType: WindowManager.ONBOARDING_WINDOW,
      title: "Account Setup",
      hidden: true, // Displayed by PageRouter::_initializeWindowSize
      frame: false, // Always false on Mac, explicitly set for Win & Linux
      toolbar: false,
      resizable: false,
      width: 900,
      height: 580,
    }

    // The SPEC_WINDOW gets passed its own bootstrapScript
    coreWinOpts[WindowManager.SPEC_WINDOW] = {
      windowKey: WindowManager.SPEC_WINDOW,
      windowType: WindowManager.SPEC_WINDOW,
      title: "Specs",
      frame: true,
      hidden: true,
      isSpec: true,
      devMode: true,
      toolbar: false,
    }

    const defaultOptions = coreWinOpts[windowKey] || {};

    return Object.assign({}, defaultOptions, extraOpts);
  }
}

WindowManager.MAIN_WINDOW = MAIN_WINDOW;
WindowManager.WORK_WINDOW = WORK_WINDOW;
WindowManager.SPEC_WINDOW = SPEC_WINDOW;
WindowManager.ONBOARDING_WINDOW = ONBOARDING_WINDOW;
