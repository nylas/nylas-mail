/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
import _ from 'underscore';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { ipcRenderer, remote } from 'electron';
import { Emitter } from 'event-kit';
import { convertStackTrace } from 'coffeestack';
import { mapSourcePosition } from 'source-map-support';

import WindowEventHandler from './window-event-handler';
import Utils from './flux/models/utils';

function ensureInteger(f, fallback) {
  let int = f;
  if (isNaN(f) || f === undefined || f === null) {
    int = fallback;
  }
  return Math.round(int);
}

// Essential: AppEnv global for dealing with packages, themes, menus, and the window.
//
// The singleton of this class is always available as the `AppEnv` global.
export default class AppEnvConstructor {
  static initClass() {
    this.version = 1;
    this.prototype.workspaceViewParentSelector = 'body';

    /*
    Section: Properties
    */

    // Public: A {CommandRegistry} instance
    this.prototype.commands = null;

    // Public: A {Config} instance
    this.prototype.config = null;

    // Public: A {MenuManager} instance
    this.prototype.menu = null;

    // Public: A {KeymapManager} instance
    this.prototype.keymaps = null;

    // Public: A {PackageManager} instance
    this.prototype.packages = null;

    // Public: A {ThemeManager} instance
    this.prototype.themes = null;

    // Public: A {StyleManager} instance
    this.prototype.styles = null; // Increment this when the serialization format changes
  }

  // Load or create the application environment
  // Returns an AppEnv instance, fully initialized
  static loadOrCreate() {
    let app;

    const savedState = this._loadSavedState();
    if (savedState && savedState.version === this.version) {
      app = new this(savedState);
    } else {
      app = new this({ version: this.version });
    }

    return app;
  }

  // Loads and returns the serialized state corresponding to this window
  // if it exists; otherwise returns undefined.
  static _loadSavedState() {
    let stateString;
    const statePath = this.getStatePath();

    if (fs.existsSync(statePath)) {
      try {
        stateString = fs.readFileSync(statePath, 'utf8');
      } catch (error) {
        console.warn(`Error reading window state: ${statePath}`, error.stack, error);
      }
    } else {
      stateString = this.getLoadSettings().windowState;
    }

    try {
      if (stateString != null) {
        return JSON.parse(stateString);
      }
    } catch (error) {
      console.warn(`Error parsing window state: ${statePath} ${error.stack}`, error);
    }
    return null;
  }

  // Returns the path where the state for the current window will be
  // located if it exists.
  static getStatePath() {
    const { isSpec, mainWindow, configDirPath } = this.getLoadSettings();
    if (isSpec) {
      return 'spec-saved-state.json';
    } else if (mainWindow) {
      return path.join(configDirPath, 'main-window-state.json');
    }
    return null;
  }

  // Returns the load settings hash associated with the current window.
  static getLoadSettings() {
    if (this.loadSettings == null) {
      this.loadSettings = JSON.parse(decodeURIComponent(window.location.search.substr(14)));
    }

    const cloned = Utils.deepClone(this.loadSettings);
    // The loadSettings.windowState could be large, request it only when needed.
    Object.defineProperty(cloned, 'windowState', {
      get: () => {
        return this.getCurrentWindow().loadSettings.windowState;
      },
      set: value => {
        this.getCurrentWindow().loadSettings.windowState = value;
        return value;
      },
    });
    return cloned;
  }

  static getCurrentWindow() {
    return remote.getCurrentWindow();
  }

  /*
  Section: Construction and Destruction
  */

  // Call .loadOrCreate instead
  constructor(savedState = {}) {
    this.savedState = savedState;
    ({ version: this.version } = this.savedState);
    this.emitter = new Emitter();
  }

  // Sets up the basic services that should be available in all modes
  // (both spec and application).
  //
  // Call after this instance has been assigned to the `AppEnv` global.
  initialize() {
    this.enhanceEventObject();

    this.setupErrorLogger();

    const { devMode, safeMode, resourcePath, configDirPath, windowType } = this.getLoadSettings();
    const specMode = this.inSpecMode();

    // Add 'src/global/' to module search path.
    const globalPath = path.join(resourcePath, 'src', 'global');
    require('module').globalPaths.push(globalPath);

    this.loadTime = null;

    const Config = require('./config');
    const KeymapManager = require('./keymap-manager').default;
    const CommandRegistry = require('./registries/command-registry').default;
    const PackageManager = require('./package-manager').default;
    const ThemeManager = require('./theme-manager').default;
    const StyleManager = require('./style-manager').default;
    const MenuManager = require('./menu-manager').default;

    document.body.classList.add(`platform-${process.platform}`);
    document.body.classList.add(`window-type-${windowType}`);

    // Make react.js faster
    if (!devMode && process.env.NODE_ENV == null) {
      process.env.NODE_ENV = 'production';
    }

    // Setup config and load it immediately so it's available to our singletons
    // and doesn't emit events later when it loads
    this.config = new Config({ configDirPath, resourcePath });
    this.loadConfig();

    this.keymaps = new KeymapManager({ configDirPath, resourcePath });
    this.commands = new CommandRegistry();
    this.packages = new PackageManager({
      devMode,
      configDirPath,
      resourcePath,
      safeMode,
      specMode,
    });
    this.styles = new StyleManager();
    this.themes = new ThemeManager({
      packageManager: this.packages,
      configDirPath,
      resourcePath,
      safeMode,
    });
    this.themes.activateThemePackage();

    this.spellchecker = require('./spellchecker').default;
    this.menu = new MenuManager({ resourcePath });
    if (process.platform === 'win32') {
      this.getCurrentWindow().setMenuBarVisibility(false);
    }

    this.windowEventHandler = new WindowEventHandler();

    // We extend nylas observables with our own methods. This happens on
    // require of mailspring-observables
    require('mailspring-observables');

    // Nylas exports is designed to provide a lazy-loaded set of globally
    // accessible objects to all packages. Upon require, mailspring-exports will
    // fill the StoreRegistry, and DatabaseObjectRegistries
    // with various constructors.
    //
    // We initialize all of the stores loaded into the StoreRegistry once
    // the window starts loading.
    require('mailspring-exports');

    const ActionBridge = require('./flux/action-bridge').default;
    this.actionBridge = new ActionBridge(ipcRenderer);

    const MailsyncBridge = require('./flux/mailsync-bridge').default;
    this.mailsyncBridge = new MailsyncBridge();

    process.title = `Mailspring ${this.getWindowType()}`;
    return this.onWindowPropsReceived(() => {
      process.title = `Mailspring ${this.getWindowType()}`;
      return process.title;
    });
  }

  // This ties window.onerror and process.un{caughtException,handledRejection}
  // to the publically callable `reportError` method. This will take care of
  // reporting errors if necessary and hooking into error handling
  // callbacks.
  //
  // Start our error reporting to the backend and attach error handlers
  // to the window and the Bluebird Promise library, converting things
  // back through the sourcemap as necessary.
  setupErrorLogger() {
    const ErrorLogger = require('./error-logger');
    this.errorLogger = new ErrorLogger({
      inSpecMode: this.inSpecMode(),
      inDevMode: this.inDevMode(),
      resourcePath: this.getLoadSettings().resourcePath,
    });

    const sourceMapCache = {};

    // https://developer.mozilla.org/en-US/docs/Web/API/GlobalEventHandlers/onerror
    window.onerror = (message, url, line, column, originalError) => {
      if (!this.inDevMode()) {
        return this.reportError(originalError, { url, line, column });
      }
      const { line: newLine, column: newColumn } = mapSourcePosition({ source: url, line, column });
      originalError.stack = convertStackTrace(originalError.stack, sourceMapCache);
      return this.reportError(originalError, { url, line: newLine, column: newColumn });
    };

    process.on('uncaughtException', e => {
      this.reportError(e);
    });

    process.on('unhandledRejection', error => {
      this._onUnhandledRejection(error, sourceMapCache);
    });

    window.addEventListener('unhandledrejection', e => {
      // This event is supposed to look like {reason, promise}, according to
      // https://developer.mozilla.org/en-US/docs/Web/API/PromiseRejectionEvent
      // In practice, it can have different shapes, so we make our best guess
      if (!e) {
        const error = new Error(`Unknown window.unhandledrejection event.`);
        this._onUnhandledRejection(error, sourceMapCache);
        return;
      }
      if (e instanceof Error) {
        this._onUnhandledRejection(e, sourceMapCache);
        return;
      }
      if (e.reason) {
        const error = e.reason;
        this._onUnhandledRejection(error, sourceMapCache);
        return;
      }
      if (e.detail && e.detail.reason) {
        const error = e.detail.reason;
        this._onUnhandledRejection(error, sourceMapCache);
        return;
      }
      const error = new Error(
        `Unrecognized event shape in window.unhandledrejection handler. Event keys: ${Object.keys(
          e
        )}`
      );
      this._onUnhandledRejection(error, sourceMapCache);
    });

    return null;
  }

  _onUnhandledRejection = (error, sourceMapCache) => {
    if (this.inDevMode()) {
      error.stack = convertStackTrace(error.stack, sourceMapCache);
    }
    this.reportError(error);
  };

  // Public: report an error through the `ErrorLogger`
  //
  // The difference between this and `ErrorLogger.reportError` is that
  // `AppEnv.reportError` hooks into test failures and dev tool popups.
  //
  reportError(error, extra = {}, { noWindows } = {}) {
    try {
      extra.pluginIds = this._findPluginsFromError(error);
    } catch (err) {
      // can happen when an error is thrown very early
      extra.pluginIds = [];
    }

    if (this.inSpecMode()) {
      if (global.jasmine || window.jasmine) {
        jasmine.getEnv().currentSpec.fail(error);
      }
    } else if (this.inDevMode() && !noWindows) {
      if (!this.isDevToolsOpened()) {
        this.openDevTools();
        this.executeJavaScriptInDevTools("DevToolsAPI.showPanel('console')");
      }
    }

    this.errorLogger.reportError(error, extra);
  }

  _findPluginsFromError(error) {
    if (!error.stack) {
      return [];
    }
    const stackPaths = error.stack.match(/((?:\/[\w-_]+)+)/g) || [];
    const stackPathComponents = _.uniq(_.flatten(stackPaths.map(p => p.split('/'))));

    const names = [];
    for (const pkg of this.packages.getActivePackages()) {
      if (stackPathComponents.includes(path.basename(pkg.directory))) {
        names.push(pkg.name);
      }
    }
    return names;
  }

  /*
  Section: Event Subscription
  */

  // Extended: Run the Chromium content-tracing module for five seconds, and save
  // the output to a file which is printed to the command-line output of the app.
  // You can take the file exported by this function and load it into Chrome's
  // content trace visualizer (chrome://tracing). It's like Chromium Developer
  // Tools Profiler, but for all processes and threads.
  trace() {
    const tracing = remote.contentTracing;
    const opts = {
      categoryFilter: '*',
      traceOptions: 'record-until-full,enable-sampling,enable-systrace',
    };
    return tracing.startRecording(opts, () => {
      console.log('Tracing started');
      return setTimeout(
        () => tracing.stopRecording('', p => console.log(`Tracing data recorded to ${p}`)),
        5000
      );
    });
  }

  isMainWindow() {
    return !!this.getLoadSettings().mainWindow;
  }

  isEmptyWindow() {
    return this.getWindowType() === 'emptyWindow';
  }

  isComposerWindow() {
    return this.getWindowType() === 'composer';
  }

  isThreadWindow() {
    return this.getWindowType() === 'thread-popout';
  }

  getWindowType() {
    return this.getLoadSettings().windowType;
  }

  // Public: Is the current window in development mode?
  inDevMode() {
    return this.getLoadSettings().devMode;
  }

  // Public: Is the current window in safe mode?
  inSafeMode() {
    return this.getLoadSettings().safeMode;
  }

  // Public: Is the current window running specs?
  inSpecMode() {
    return this.getLoadSettings().isSpec;
  }

  // Public: Get the version of Mailspring.
  //
  // Returns the version text {String}.
  getVersion() {
    return this.appVersion != null
      ? this.appVersion
      : (this.appVersion = this.getLoadSettings().appVersion);
  }

  // Public: Determine whether the current version is an official release.
  isReleasedVersion() {
    // Check if the release contains a 7-character SHA prefix
    return !/\w{7}/.test(this.getVersion());
  }

  // Public: Get the directory path to Mailspring's configuration area.
  getConfigDirPath() {
    return this.getLoadSettings().configDirPath;
  }

  // Public: Get the time taken to completely load the current window.
  //
  // This time include things like loading and activating packages, creating
  // DOM elements for the editor, and reading the config.
  //
  // Returns the {Number} of milliseconds taken to load the window or null
  // if the window hasn't finished loading yet.
  getWindowLoadTime() {
    return this.loadTime;
  }

  // Public: Get the load settings for the current window.
  //
  // Returns an {Object} containing all the load setting key/value pairs.
  getLoadSettings() {
    return this.constructor.getLoadSettings();
  }

  /*
  Section: Managing The Nylas Window
  */

  // Essential: Close the current window.
  close() {
    return this.getCurrentWindow().close();
  }

  quit() {
    return remote.app.quit();
  }

  // Essential: Get the size of current window.
  //
  // Returns an {Object} in the format `{width: 1000, height: 700}`
  getSize() {
    const [width, height] = Array.from(this.getCurrentWindow().getSize());
    return { width, height };
  }

  // Essential: Set the size of current window.
  //
  // * `width` The {Number} of pixels.
  // * `height` The {Number} of pixels.
  setSize(width, height) {
    return this.getCurrentWindow().setSize(ensureInteger(width, 100), ensureInteger(height, 100));
  }

  // Essential: Transition and set the size of the current window.
  //
  // * `width` The {Number} of pixels.
  // * `height` The {Number} of pixels.
  // * `duration` The {Number} of pixels.
  setSizeAnimated(width, height, duration = 400) {
    // On Windows, the native window resizing code isn't fast enough to "animate"
    // by resizing over and over again. Just turn off animation for now.
    let animDuration = duration;
    if (process.platform === 'win32') {
      animDuration = 1;
    }

    // Avoid divide by zero errors below
    animDuration = Math.max(1, duration);

    // Keep track of the number of times this method has been invoked, and ensure
    // that we only `tick` for the last invocation. This prevents two resizes from
    // running at the same time.
    if (this._setSizeAnimatedCallCount == null) {
      this._setSizeAnimatedCallCount = 0;
    }
    this._setSizeAnimatedCallCount += 1;
    const call = this._setSizeAnimatedCallCount;

    const cubicInOut = t => {
      if (t < 0.5) {
        return 4 * t ** 3;
      }
      return (t - 1) * (2 * t - 2) ** 2 + 1;
    };
    const win = this.getCurrentWindow();
    const animWidth = Math.round(width);
    const animHeight = Math.round(height);

    const startBounds = win.getBounds();
    const startTime = Date.now() - 1; // - 1 so that if animDuration is 1, t = 1 on the first frame

    const boundsForI = i =>
      // It's very important this function never return undefined for any of the
      // keys which blows up setBounds.
      ({
        x: ensureInteger(startBounds.x + (animWidth - startBounds.animWidth) * -0.5 * i, 0),
        y: ensureInteger(startBounds.y + (animHeight - startBounds.animHeight) * -0.5 * i, 0),
        width: ensureInteger(
          startBounds.animWidth + (animWidth - startBounds.animWidth) * i,
          animWidth
        ),
        height: ensureInteger(
          startBounds.animHeight + (animHeight - startBounds.animHeight) * i,
          animHeight
        ),
      });

    const tick = () => {
      if (call !== this._setSizeAnimatedCallCount) {
        return;
      }
      const t = Math.min(1, (Date.now() - startTime) / animDuration);
      const i = cubicInOut(t);
      win.setBounds(boundsForI(i));
      if (t !== 1) {
        _.defer(tick);
      }
    };
    tick();
  }

  setMinimumWidth(minWidth) {
    const win = this.getCurrentWindow();
    const minHeight = win.getMinimumSize()[1];
    win.setMinimumSize(ensureInteger(minWidth, 0), minHeight);

    const [currWidth, currHeight] = Array.from(win.getSize());
    if (minWidth > currWidth) {
      win.setSize(minWidth, currHeight);
    }
  }

  // Essential: Get the position of current window.
  //
  // Returns an {Object} in the format `{x: 10, y: 20}`
  getPosition() {
    const [x, y] = Array.from(this.getCurrentWindow().getPosition());
    return { x, y };
  }

  // Essential: Set the position of current window.
  //
  // * `x` The {Number} of pixels.
  // * `y` The {Number} of pixels.
  setPosition(x, y) {
    return ipcRenderer.send(
      'call-window-method',
      'setPosition',
      ensureInteger(x, 0),
      ensureInteger(y, 0)
    );
  }

  // Extended: Get the current window
  getCurrentWindow() {
    return this.constructor.getCurrentWindow();
  }

  // Extended: Move current window to the center of the screen.
  center() {
    if (os.platform() === 'linux') {
      let dimensions = this.getWindowDimensions();
      let bounds = remote.screen.getDisplayMatching(dimensions).bounds;
      let x = bounds.x + ((bounds.width - dimensions.width) / 2);
      let y = bounds.y + ((bounds.height - dimensions.height) / 2);

      return this.setPosition(x, y);
    } else {
      return ipcRenderer.send('call-window-method', 'center');
    }
  }

  // Extended: Focus the current window. Note: this will not open the window
  // if it is hidden.
  focus() {
    ipcRenderer.send('call-window-method', 'focus');
    return window.focus();
  }

  // Extended: Show the current window.
  show() {
    return ipcRenderer.send('call-window-method', 'show');
  }

  isVisible() {
    return this.getCurrentWindow().isVisible();
  }

  // Extended: Hide the current window.
  hide() {
    return ipcRenderer.send('call-window-method', 'hide');
  }

  // Extended: Reload the current window.
  reload() {
    this.isReloading = true;
    return ipcRenderer.send('call-webcontents-method', 'reload');
  }

  // Public: The windowProps passed when creating the window via `newWindow`.
  //
  getWindowProps() {
    return this.getLoadSettings().windowProps || {};
  }

  // Public: If your package declares hot-loaded window types, `onWindowPropsReceived`
  // fires when your hot-loaded window is about to be shown so you can update
  // components to reflect the new window props.
  //
  // - callback: A function to call when window props are received, just before
  //   the hot window is shown. The first parameter is the new windowProps.
  //
  onWindowPropsReceived(callback) {
    return this.emitter.on('window-props-received', callback);
  }

  // Extended: Is the current window maximized?
  isMaximixed() {
    return this.getCurrentWindow().isMaximized();
  }

  maximize() {
    return ipcRenderer.send('call-window-method', 'maximize');
  }

  minimize() {
    return ipcRenderer.send('call-window-method', 'minimize');
  }

  // Extended: Is the current window in full screen mode?
  isFullScreen() {
    return this.getCurrentWindow().isFullScreen();
  }

  // Extended: Set the full screen state of the current window.
  setFullScreen(fullScreen = false) {
    ipcRenderer.send('call-window-method', 'setFullScreen', fullScreen);
    if (fullScreen) {
      return document.body.classList.add('fullscreen');
    }
    return document.body.classList.remove('fullscreen');
  }

  // Extended: Toggle the full screen state of the current window.
  toggleFullScreen() {
    return this.setFullScreen(!this.isFullScreen());
  }

  // Get the dimensions of this window.
  //
  // Returns an {Object} with the following keys:
  //   * `x`      The window's x-position {Number}.
  //   * `y`      The window's y-position {Number}.
  //   * `width`  The window's width {Number}.
  //   * `height` The window's height {Number}.
  getWindowDimensions() {
    const browserWindow = this.getCurrentWindow();
    const { x, y, width, height } = browserWindow.getBounds();
    const maximized = browserWindow.isMaximized();
    const fullScreen = browserWindow.isFullScreen();
    return { x, y, width, height, maximized, fullScreen };
  }

  // Set the dimensions of the window.
  //
  // The window will be centered if either the x or y coordinate is not set
  // in the dimensions parameter. If x or y are omitted the window will be
  // centered. If height or width are omitted only the position will be changed.
  //
  // * `dimensions` An {Object} with the following keys:
  //   * `x` The new x coordinate.
  //   * `y` The new y coordinate.
  //   * `width` The new width.
  //   * `height` The new height.
  setWindowDimensions({ x, y, width, height }) {
    if (x != null && y != null && width != null && height != null) {
      return this.getCurrentWindow().setBounds({ x, y, width, height });
    } else if (width != null && height != null) {
      return this.setSize(width, height);
    } else if (x != null && y != null) {
      return this.setPosition(x, y);
    }
    return this.center();
  }

  // Returns true if the dimensions are useable, false if they should be ignored.
  // Work around for https://github.com/atom/electron/issues/473
  isValidDimensions({ x, y, width, height } = {}) {
    return width > 0 && height > 0 && x + width > 0 && y + height > 0;
  }

  getDefaultWindowDimensions() {
    let { width, height } = remote.screen.getPrimaryDisplay().workAreaSize;
    let x = 0;
    let y = 0;

    const MAX_WIDTH = 1440;
    if (width > MAX_WIDTH) {
      x = Math.floor((width - MAX_WIDTH) / 2);
      width = MAX_WIDTH;
    }

    const MAX_HEIGHT = 900;
    if (height > MAX_HEIGHT) {
      y = Math.floor((height - MAX_HEIGHT) / 2);
      height = MAX_HEIGHT;
    }

    return { x, y, width, height };
  }

  restoreWindowDimensions() {
    let dimensions = this.savedState.windowDimensions;
    if (!this.isValidDimensions(dimensions)) {
      dimensions = this.getDefaultWindowDimensions();
    }
    this.setWindowDimensions(dimensions);
    if (dimensions.maximized && process.platform !== 'darwin') {
      this.maximize();
    }
    if (dimensions.fullScreen) {
      this.setFullScreen(true);
    }
  }

  storeWindowDimensions() {
    const dimensions = this.getWindowDimensions();
    if (this.isValidDimensions(dimensions)) {
      this.savedState.windowDimensions = dimensions;
    }
  }

  storeColumnWidth({ id, width }) {
    if (this.savedState.columnWidths == null) {
      this.savedState.columnWidths = {};
    }
    this.savedState.columnWidths[id] = width;
  }

  getColumnWidth(id) {
    if (this.savedState.columnWidths == null) {
      this.savedState.columnWidths = {};
    }
    return this.savedState.columnWidths[id];
  }

  async startWindow() {
    const { windowType } = this.getLoadSettings();

    this.themes.loadStaticStylesheets();
    this.initializeBasicSheet();
    this.initializeReactRoot();
    this.packages.activatePackages(windowType);

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          window.requestAnimationFrame(() => {
            this.keymaps.loadKeymaps();
            this.menu.update();

            ipcRenderer.send('window-command', 'window:loaded');
          });
        });
      });
    });
  }

  // Call this method when establishing a real application window.
  async startRootWindow() {
    this.restoreWindowDimensions();
    this.getCurrentWindow().setMinimumSize(875, 250);
    await this.startWindow();
  }

  // Initializes a secondary window.
  // NOTE: If the `packageLoadingDeferred` option is set (which is true for
  // hot windows), the packages won't be loaded until `populateHotWindow`
  // gets fired.
  async startSecondaryWindow() {
    await this.startWindow();
    ipcRenderer.on('load-settings-changed', (...args) => this.populateHotWindow(...args));
  }

  // We setup the initial Sheet for hot windows. This is the default title
  // bar, stoplights, etc. This saves ~100ms when populating the hot
  // windows.
  initializeBasicSheet() {
    const WorkspaceStore = require('../src/flux/stores/workspace-store');
    if (!WorkspaceStore.Sheet.Main) {
      WorkspaceStore.defineSheet(
        'Main',
        { root: true },
        {
          popout: ['Center'],
        }
      );
    }
  }

  // Updates the window load settings - called when the app is ready to
  // display a hot-loaded window. Causes listeners registered with
  // `onWindowPropsReceived` to receive new window props.
  //
  // This also means that the windowType has changed and a different set of
  // plugins needs to be loaded.
  populateHotWindow(event, loadSettings) {
    this.loadSettings = loadSettings;
    this.constructor.loadSettings = loadSettings;

    this.packages.activatePackages(loadSettings.windowType);

    this.emitter.emit(
      'window-props-received',
      loadSettings.windowProps != null ? loadSettings.windowProps : {}
    );

    const browserWindow = this.getCurrentWindow();
    if (browserWindow.isResizable() !== loadSettings.resizable) {
      browserWindow.setResizable(loadSettings.resizable);
    }

    if (!loadSettings.hidden) {
      this.displayWindow();
    }
  }

  // Launches a new window via the browser/WindowLauncher.
  //
  // If you pass a `windowKey` in the options, and that windowKey already
  // exists, it'll show that window instead of spawing a new one. This is
  // useful for places like popout composer windows where you want to
  // simply display the draft instead of spawning a whole new window for
  // the same draft.
  //
  // `options` are documented in browser/WindowLauncher
  newWindow(options = {}) {
    return ipcRenderer.send('new-window', options);
  }

  saveStateAndUnloadWindow() {
    this.packages.deactivatePackages();
    this.saveSync();
    this.windowState = null;
  }

  /*
  Section: Messaging the User
  */

  displayWindow({ maximize } = {}) {
    if (this.inSpecMode()) {
      return;
    }
    this.show();
    this.focus();
    if (maximize) this.maximize();
  }

  /*
  Section: Managing the Dev Tools
  */

  // Extended: Open the dev tools for the current window.
  openDevTools() {
    return ipcRenderer.send('call-webcontents-method', 'openDevTools');
  }

  isDevToolsOpened() {
    return this.getCurrentWindow().webContents.isDevToolsOpened();
  }

  // Extended: Toggle the visibility of the dev tools for the current window.
  toggleDevTools() {
    return ipcRenderer.send('call-webcontents-method', 'toggleDevTools');
  }

  // Extended: Execute code in dev tools.
  executeJavaScriptInDevTools(code) {
    return ipcRenderer.send('call-devtools-webcontents-method', 'executeJavaScript', code);
  }

  /*
  Section: Private
  */

  initializeReactRoot() {
    // Put state back into sheet-container? Restore app state here
    this.item = document.createElement('nylas-workspace');
    this.item.setAttribute('id', 'sheet-container');
    this.item.setAttribute('class', 'sheet-container');
    this.item.setAttribute('tabIndex', '-1');

    const React = require('react');
    const ReactDOM = require('react-dom');
    const SheetContainer = require('./sheet-container').default;
    ReactDOM.render(React.createElement(SheetContainer), this.item);
    return document.querySelector(this.workspaceViewParentSelector).appendChild(this.item);
  }

  loadConfig() {
    this.config.setSchema(null, {
      type: 'object',
      properties: _.clone(require('./config-schema').default),
    });
    return this.config.load();
  }

  exit(status) {
    remote.app.emit('will-exit');
    return remote.process.exit(status);
  }

  showOpenDialog(options, callback) {
    return callback(remote.dialog.showOpenDialog(this.getCurrentWindow(), options));
  }

  showSaveDialog(options, callback) {
    if (options.title == null) {
      options.title = 'Save File';
    }
    return callback(remote.dialog.showSaveDialog(this.getCurrentWindow(), options));
  }

  showErrorDialog(messageData, { showInMainWindow, detail } = {}) {
    let message;
    let title;
    if (_.isString(messageData) || _.isNumber(messageData)) {
      message = messageData;
      title = 'Error';
    } else if (_.isObject(messageData)) {
      ({ message } = messageData);
      ({ title } = messageData);
    } else {
      throw new Error('Must pass a valid message to show dialog', message);
    }

    let winToShow = null;
    if (showInMainWindow) {
      winToShow = remote.getGlobal('application').getMainWindow();
    }

    if (!detail) {
      return remote.dialog.showMessageBox(winToShow, {
        type: 'warning',
        buttons: ['Okay'],
        message: title,
        detail: message,
      });
    }
    return remote.dialog.showMessageBox(
      winToShow,
      {
        type: 'warning',
        buttons: ['Okay', 'Show Details'],
        message: title,
        detail: message,
      },
      buttonIndex => {
        if (buttonIndex === 1) {
          const { Actions } = require('mailspring-exports');
          const { CodeSnippet } = require('mailspring-component-kit');
          Actions.openModal({
            component: CodeSnippet({ intro: message, code: detail, className: 'error-details' }),
            width: 500,
            height: 300,
          });
        }
      }
    );
  }

  // Delegate to the browser's process fileListCache
  fileListCache() {
    return remote.getGlobal('application').fileListCache;
  }

  saveSync() {
    const stateString = JSON.stringify(this.savedState);
    const statePath = this.constructor.getStatePath();
    if (statePath) {
      return fs.writeFileSync(statePath, stateString, 'utf8');
    }
    this.getCurrentWindow().loadSettings.windowState = stateString;
    return stateString;
  }

  crashMainProcess() {
    return remote.process.crash();
  }

  crashRenderProcess() {
    return process.crash();
  }

  onUpdateAvailable(callback) {
    return this.emitter.on('update-available', callback);
  }

  updateAvailable(details) {
    return this.emitter.emit('update-available', details);
  }

  // Lets multiple components register beforeUnload callbacks.
  // The callbacks are expected to return either true or false.
  //
  // Note: If you return false to cancel the window close, you /must/ perform
  // work and then call finishUnload. We do not support cancelling quit!
  // https://phab.nylas.com/D1932#inline-11722
  //
  // Also see logic in browser/MailspringWindow::handleEvents where we listen
  // to the browserWindow.on 'close' event to catch "unclosable" windows.
  onBeforeUnload(callback) {
    return this.windowEventHandler.addUnloadCallback(callback);
  }

  removeUnloadCallback(callback) {
    return this.windowEventHandler.removeUnloadCallback(callback);
  }

  enhanceEventObject() {
    const overriddenStop = Event.prototype.stopPropagation;
    Event.prototype.stopPropagation = function stopPropagation(...args) {
      this.propagationStopped = true;
      return overriddenStop.apply(this, args);
    };
    Event.prototype.isPropagationStopped = function isPropagationStopped() {
      return this.propagationStopped;
    };
  }

  registerGlobalActions(...args) {
    if (this.inSpecMode()) {
      return;
    }
    this.actionBridge.registerGlobalActions(...args);
  }
}

AppEnvConstructor.initClass();
