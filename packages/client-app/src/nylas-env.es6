/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
import path from 'path';

import { ipcRenderer, remote, shell } from 'electron';

import _ from 'underscore';
import { Emitter } from 'event-kit';
import fs from 'fs-plus';
import { convertStackTrace } from 'coffeestack';
import { mapSourcePosition } from 'source-map-support';

import WindowEventHandler from './window-event-handler';
import StylesElement from './styles-element';
import StoreRegistry from './registries/store-registry';

import Utils from './flux/models/utils';

function ensureInteger(f, fallback) {
  let int = f;
  if (isNaN(f) || (f === undefined) || (f === null)) {
    int = fallback;
  }
  return Math.round(int);
}

// Essential: NylasEnv global for dealing with packages, themes, menus, and the window.
//
// The singleton of this class is always available as the `NylasEnv` global.
export default class NylasEnvConstructor {
  static initClass() {
    this.version = 1;

    this.prototype.workspaceViewParentSelector = 'body';
    this.prototype.lastUncaughtError = null;

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
    this.prototype.styles = null;  // Increment this when the serialization format changes
  }

  assert(bool, msg) {
    if (!bool) { throw new Error(`Assertion error: ${msg}`); }
  }

  // Load or create the application environment
  // Returns an NylasEnv instance, fully initialized
  static loadOrCreate() {
    let app;

    const savedState = this._loadSavedState();
    if (savedState && (savedState.version === this.version)) {
      app = new this(savedState);
    } else {
      app = new this({version: this.version});
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
      if (stateString != null) { return JSON.parse(stateString); }
    } catch (error) {
      console.warn(`Error parsing window state: ${statePath} ${error.stack}`, error);
    }
    return null;
  }

  // Returns the path where the state for the current window will be
  // located if it exists.
  static getStatePath() {
    const {isSpec, mainWindow, configDirPath} = this.getLoadSettings();
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
      this.loadSettings = JSON.parse(decodeURIComponent(location.search.substr(14)));
    }

    const cloned = Utils.deepClone(this.loadSettings);
    // The loadSettings.windowState could be large, request it only when needed.
    Object.defineProperty(cloned, 'windowState', {
      get: () => { return this.getCurrentWindow().loadSettings.windowState },
      set: (value) => {
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
    this.reportError = this.reportError.bind(this);
    this.getConfigDirPath = this.getConfigDirPath.bind(this);
    this.storeColumnWidth = this.storeColumnWidth.bind(this);
    this.getColumnWidth = this.getColumnWidth.bind(this);
    this.startWindow = this.startWindow.bind(this);
    this.populateHotWindow = this.populateHotWindow.bind(this);
    this.savedState = savedState;
    ({version: this.version} = this.savedState);
    this.emitter = new Emitter();
  }

  // Sets up the basic services that should be available in all modes
  // (both spec and application).
  //
  // Call after this instance has been assigned to the `NylasEnv` global.
  initialize() {
    this.enhanceEventObject();

    this.setupErrorLogger();

    this.loadTime = null;

    const Config = require('./config');
    const KeymapManager = require('./keymap-manager').default;
    const CommandRegistry = require('./registries/command-registry').default;
    const PackageManager = require('./package-manager');
    const ThemeManager = require('./theme-manager');
    const StyleManager = require('./style-manager');
    const ActionBridge = require('./flux/action-bridge').default;
    const MenuManager = require('./menu-manager').default;

    const {devMode, safeMode, resourcePath, configDirPath, windowType} = this.getLoadSettings();

    document.body.classList.add(`platform-${process.platform}`);
    document.body.classList.add(`window-type-${windowType}`);

    // Add 'src/global' to module search path.
    const globalPath = path.join(resourcePath, 'src', 'global');
    require('module').globalPaths.push(globalPath);

    // Our client-private-plugins get sym-linked into internal_packages.
    // However, when we require anything from those files, the require chain is
    // relative to their original location. Their original location is a sibling
    // (not a child) of the client-app repo. This means the node_modules that
    // they should see aren't actually there due to the symlink. We manually add
    // node_modules to the global require path (even though it's already there
    // by default) to support these symlinked modules
    require('module').globalPaths.push(path.join(resourcePath, 'node_modules'));

    // Still set NODE_PATH since tasks may need it.
    process.env.NODE_PATH = globalPath;

    // Make react.js faster
    if (!devMode && process.env.NODE_ENV == null) process.env.NODE_ENV = 'production';

    // Set NylasEnv's home so packages don't have to guess it
    process.env.NYLAS_HOME = configDirPath;

    // Setup config and load it immediately so it's available to our singletons
    this.config = new Config({configDirPath, resourcePath});

    this.keymaps = new KeymapManager({configDirPath, resourcePath});

    const specMode = this.inSpecMode();

    this.commands = new CommandRegistry();
    this.packages = new PackageManager({devMode, configDirPath, resourcePath, safeMode, specMode});
    this.styles = new StyleManager();
    document.head.appendChild(new StylesElement());
    this.themes = new ThemeManager({packageManager: this.packages, configDirPath, resourcePath, safeMode});
    this.menu = new MenuManager({resourcePath});
    if (process.platform === 'win32') {
      this.getCurrentWindow().setMenuBarVisibility(false);
    }

    // initialize spell checking
    this.spellchecker = require('./spellchecker').default;

    this.packages.onDidActivateInitialPackages(() => this.watchThemes());
    this.windowEventHandler = new WindowEventHandler();

    this.timer = remote.getGlobal('application').timer;

    this.globalWindowEmitter = new Emitter();

    if (!this.inSpecMode()) {
      this.actionBridge = new ActionBridge(ipcRenderer);
    }

    this.extendRxObservables();

    // Nylas exports is designed to provide a lazy-loaded set of globally
    // accessible objects to all packages. Upon require, nylas-exports will
    // fill the TaskRegistry, StoreRegistry, and DatabaseObjectRegistries
    // with various constructors.
    //
    // We initialize all of the stores loaded into the StoreRegistry once
    // the window starts loading.
    require('nylas-exports');

    process.title = `Nylas Mail ${this.getWindowType()}`;
    return this.onWindowPropsReceived(() => {
      process.title = `Nylas Mail ${this.getWindowType()}`;
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
        return this.reportError(originalError, {url, line, column});
      }
      const {line: newLine, column: newColumn} = mapSourcePosition({source: url, line, column});
      originalError.stack = convertStackTrace(originalError.stack, sourceMapCache);
      return this.reportError(originalError, {url, line: newLine, column: newColumn});
    };

    process.on('uncaughtException', e => this.reportError(e));

    // We use the native Node 'unhandledRejection' instead of Bluebird's
    // `Promise.onPossiblyUnhandledRejection`. Testing indicates that
    // the Node process method is a strict superset of Bluebird's handler.
    // With the introduction of transpiled async/await, it is now possible
    // to get a native, non-Bluebird Promise. In that case, Bluebird's
    // `onPossiblyUnhandledRejection` gets bypassed and we miss some
    // errors. The Node process handler catches all Bluebird promises plus
    // those created with a native Promise.
    process.on('unhandledRejection', error => {
      if (this.inDevMode()) {
        error.stack = convertStackTrace(error.stack, sourceMapCache);
      }
      return this.reportError(error);
    });

    if (this.inSpecMode() || this.inDevMode()) {
      return Promise.config({longStackTraces: true});
    }
    return null;
  }

  _createErrorCallbackEvent(error, extraArgs = {}) {
    const event = _.extend({}, extraArgs, {
      message: error.message,
      originalError: error,
      defaultPrevented: false,
    });
    event.preventDefault = () => { event.defaultPrevented = true; return true };
    return event;
  }

  // Public: report an error through the `ErrorLogger`
  //
  // Takes an error and an extra object to report. Hooks into the
  // `onWillThrowError` and `onDidThrowError` callbacks. If someone
  // registered with `onWillThrowError` calls `preventDefault` on the event
  // object it's given, then no error will be reported.
  //
  // The difference between this and `ErrorLogger.reportError` is that
  // `NylasEnv.reportError` will hook into the event callbacks and handle
  // test failures and dev tool popups.
  reportError(error, extra = {}, {noWindows} = {}) {
    const event = this._createErrorCallbackEvent(error, extra);
    this.emitter.emit('will-throw-error', event);
    if (event.defaultPrevented) { return; }

    console.error(error.stack, extra);
    this.lastUncaughtError = error;

    extra.pluginIds = this._findPluginsFromError(error);

    if (this.inSpecMode()) {
      jasmine.getEnv().currentSpec.fail(error);
    } else if (this.inDevMode() && !noWindows) {
      this.openDevTools();
      this.executeJavaScriptInDevTools("DevToolsAPI.showPanel('console')");
    }

    this.errorLogger.reportError(error, extra);

    this.emitter.emit('did-throw-error', event);
  }

  _findPluginsFromError(error) {
    if (!error.stack) { return []; }
    const left = error.stack.match(/((?:\/[\w-_]+)+)/g);
    const stackPaths = left || [];
    const stackTokens = _.uniq(_.flatten(stackPaths.map(p => p.split("/"))));
    const pluginIdsByPathBase = this.packages.getPluginIdsByPathBase();
    const tokens = _.intersection(Object.keys(pluginIdsByPathBase), stackTokens);
    return tokens.map(tok => pluginIdsByPathBase[tok]);
  }

  /*
  Section: Event Subscription
  */

  // Extended: Invoke the given callback whenever {::beep} is called.
  //
  // * `callback` {Function} to be called whenever {::beep} is called.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidBeep(callback) {
    return this.emitter.on('did-beep', callback);
  }

  // Extended: Invoke the given callback when there is an unhandled error, but
  // before the devtools pop open
  //
  // * `callback` {Function} to be called whenever there is an unhandled error
  //   * `event` {Object}
  //     * `originalError` {Object} the original error object
  //     * `message` {String} the original error object
  //     * `url` {String} Url to the file where the error originated.
  //     * `line` {Number}
  //     * `column` {Number}
  //     * `preventDefault` {Function} call this to avoid popping up the dev tools.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillThrowError(callback) {
    return this.emitter.on('will-throw-error', callback);
  }

  // Extended: Invoke the given callback whenever there is an unhandled error.
  //
  // * `callback` {Function} to be called whenever there is an unhandled error
  //   * `event` {Object}
  //     * `originalError` {Object} the original error object
  //     * `message` {String} the original error object
  //     * `url` {String} Url to the file where the error originated.
  //     * `line` {Number}
  //     * `column` {Number}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidThrowError(callback) {
    return this.emitter.on('did-throw-error', callback);
  }

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
      return setTimeout(() =>
        tracing.stopRecording('', p => console.log(`Tracing data recorded to ${p}`))

      , 5000);
    });
  }

  isMainWindow() {
    return !!this.getLoadSettings().mainWindow;
  }

  isEmptyWindow() {
    return this.getWindowType() === 'emptyWindow';
  }

  isWorkWindow() {
    return this.getWindowType() === 'work';
  }

  isComposerWindow() {
    return ["composer", "composer-preload"].includes(this.getWindowType());
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

  // Public: Get the version of Nylas Mail.
  //
  // Returns the version text {String}.
  getVersion() {
    return this.appVersion != null ? this.appVersion : (this.appVersion = this.getLoadSettings().appVersion);
  }

  // Public: Determine whether the current version is an official release.
  isReleasedVersion() {
    return !/\w{7}/.test(this.getVersion()); // Check if the release is a 7-character SHA prefix
  }

  // Public: Get the directory path to Nylas Mail's configuration area.
  getConfigDirPath() { return this.getLoadSettings().configDirPath; }

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
    return {width, height};
  }

  // Essential: Set the size of current window.
  //
  // * `width` The {Number} of pixels.
  // * `height` The {Number} of pixels.
  setSize(width, height) {
    return this.getCurrentWindow().setSize(
      ensureInteger(width, 100),
      ensureInteger(height, 100));
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

    const cubicInOut = (t) => {
      if (t < 0.5) {
        return 4 * (t ** 3);
      }
      return (t - 1) * (((2 * t) - 2) ** 2) + 1;
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
        x: ensureInteger(startBounds.x + ((animWidth - startBounds.animWidth) * -0.5 * i), 0),
        y: ensureInteger(startBounds.y + ((animHeight - startBounds.animHeight) * -0.5 * i), 0),
        width: ensureInteger(startBounds.animWidth + ((animWidth - startBounds.animWidth) * i), animWidth),
        height: ensureInteger(startBounds.animHeight + ((animHeight - startBounds.animHeight) * i), animHeight),
      })
    ;

    const tick = () => {
      if (call !== this._setSizeAnimatedCallCount) { return; }
      const t = Math.min(1, (Date.now() - startTime) / (animDuration));
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
    return {x, y};
  }

  // Essential: Set the position of current window.
  //
  // * `x` The {Number} of pixels.
  // * `y` The {Number} of pixels.
  setPosition(x, y) {
    return ipcRenderer.send('call-window-method', 'setPosition',
      ensureInteger(x, 0),
      ensureInteger(y, 0));
  }

  // Extended: Get the current window
  getCurrentWindow() {
    return this.constructor.getCurrentWindow();
  }

  // Extended: Move current window to the center of the screen.
  center() {
    return ipcRenderer.send('call-window-method', 'center');
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
      return document.body.classList.add("fullscreen");
    }
    return document.body.classList.remove("fullscreen");
  }

  // Extended: Toggle the full screen state of the current window.
  toggleFullScreen() {
    return this.setFullScreen(!this.isFullScreen());
  }

  getAllWindowDimensions() {
    return remote.getGlobal('application').getAllWindowDimensions();
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
    const {x, y, width, height} = browserWindow.getBounds();
    const maximized = browserWindow.isMaximized();
    const fullScreen = browserWindow.isFullScreen();
    return {x, y, width, height, maximized, fullScreen};
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
  setWindowDimensions({x, y, width, height}) {
    if ((x != null) && (y != null) && (width != null) && (height != null)) {
      return this.getCurrentWindow().setBounds({x, y, width, height});
    } else if ((width != null) && (height != null)) {
      return this.setSize(width, height);
    } else if ((x != null) && (y != null)) {
      return this.setPosition(x, y);
    }
    return this.center();
  }

  // Returns true if the dimensions are useable, false if they should be ignored.
  // Work around for https://github.com/atom/electron/issues/473
  isValidDimensions({x, y, width, height} = {}) {
    return (width > 0) && (height > 0) && ((x + width) > 0) && ((y + height) > 0);
  }

  getDefaultWindowDimensions() {
    let {width, height} = remote.screen.getPrimaryDisplay().workAreaSize;
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

    return {x, y, width, height};
  }

  restoreWindowDimensions() {
    let dimensions = this.savedState.windowDimensions;
    if (!this.isValidDimensions(dimensions)) {
      dimensions = this.getDefaultWindowDimensions();
    }
    this.setWindowDimensions(dimensions);
    if (dimensions.maximized && (process.platform !== 'darwin')) {
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

  storeColumnWidth({id, width}) {
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

  startWindow() {
    this.loadConfig();
    const {packageLoadingDeferred, windowType} = this.getLoadSettings();
    return StoreRegistry.activateAllStores().then(() => {
      this.keymaps.loadKeymaps();
      this.themes.loadBaseStylesheets();
      if (!packageLoadingDeferred) { this.packages.loadPackages(windowType); }
      if (!packageLoadingDeferred) { this.deserializePackageStates(); }
      this.initializeReactRoot();
      if (!packageLoadingDeferred) { this.packages.activate(); }
      return this.menu.update();
    }
    );
  }

  // Call this method when establishing a real application window.
  startRootWindow() {
    const {safeMode, initializeInBackground} = this.getLoadSettings();

    // Temporary. It takes five paint cycles for all the CSS in index.html to
    // be applied. Remove if https://github.com/atom/brightray/issues/196 fixed!
    return window.requestAnimationFrame(() => {
      return window.requestAnimationFrame(() => {
        return window.requestAnimationFrame(() => {
          return window.requestAnimationFrame(() => {
            return window.requestAnimationFrame(() => {
              if (!initializeInBackground) { this.displayWindow(); }
              return this.startWindow().then(() => {
                // These don't need to wait for the window's stores and
                // such to fully activate:
                if (!safeMode) { this.requireUserInitScript(); }
                this.showMainWindow();
                return ipcRenderer.send('window-command', 'window:loaded');
              });
            });
          });
        });
      });
    });
  }

  // Initializes a secondary window.
  // NOTE: If the `packageLoadingDeferred` option is set (which is true for
  // hot windows), the packages won't be loaded until `populateHotWindow`
  // gets fired.
  startSecondaryWindow() {
    const elt = document.getElementById("application-loading-cover");
    if (elt) elt.remove();

    return this.startWindow().then(() => {
      this.initializeBasicSheet();
      ipcRenderer.on("load-settings-changed", this.populateHotWindow);
      return ipcRenderer.send('window-command', 'window:loaded');
    }
    );
  }

  // We setup the initial Sheet for hot windows. This is the default title
  // bar, stoplights, etc. This saves ~100ms when populating the hot
  // windows.
  initializeBasicSheet() {
    const WorkspaceStore = require('../src/flux/stores/workspace-store');
    if (!WorkspaceStore.Sheet.Main) {
      WorkspaceStore.defineSheet('Main', {root: true}, {
        popout: ['Center'],
      });
    }
  }

  showMainWindow() {
    document.getElementById("application-loading-cover").remove();
    document.body.classList.add("window-loaded");
    this.restoreWindowDimensions();
    return this.getCurrentWindow().setMinimumSize(875, 250);
  }

  // Updates the window load settings - called when the app is ready to
  // display a hot-loaded window. Causes listeners registered with
  // `onWindowPropsReceived` to receive new window props.
  //
  // This also means that the windowType has changed and a different set of
  // plugins needs to be loaded.
  populateHotWindow(event, loadSettings) {
    if (/composer/.test(loadSettings.windowType)) {
      NylasEnv.timer.split('open-composer-window');
    }
    this.loadSettings = loadSettings;
    this.constructor.loadSettings = loadSettings;

    this.packages.loadPackages(loadSettings.windowType);
    this.deserializePackageStates();
    this.packages.activate();

    this.emitter.emit('window-props-received',
      loadSettings.windowProps != null ? loadSettings.windowProps : {});

    const browserWindow = this.getCurrentWindow();
    if (browserWindow.isResizable() !== loadSettings.resizable) {
      browserWindow.setResizable(loadSettings.resizable);
    }

    if (!loadSettings.hidden) {
      this.displayWindow();
    }
  }

  // We extend nylas observables with our own methods. This happens on
  // require of nylas-observables
  extendRxObservables() {
    return require('nylas-observables');
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
    this.savedState.packageStates = this.packages.packageStates;
    this.saveSync();
    this.windowState = null;
  }

  /*
  Section: Messaging the User
  */

  displayWindow({maximize} = {}) {
    if (this.inSpecMode()) { return; }
    this.show();
    this.focus();
    if (maximize) this.maximize();
  }

  // Essential: Visually and audibly trigger a beep.
  beep() {
    if (this.config.get('core.audioBeep')) { shell.beep(); }
    return this.emitter.emit('did-beep');
  }

  // Essential: A flexible way to open a dialog akin to an alert dialog.
  //
  // ## Examples
  //
  // ```coffee
  // NylasEnv.confirm
  //   message: 'How you feeling?'
  //   detailedMessage: 'Be honest.'
  //   buttons:
  //     Good: -> window.alert('good to hear')
  //     Bad: -> window.alert('bummer')
  // ```
  //
  // * `options` An {Object} with the following keys:
  //   * `message` The {String} message to display.
  //   * `detailedMessage` (optional) The {String} detailed message to display.
  //   * `buttons` (optional) Either an array of strings or an object where keys are
  //     button names and the values are callbacks to invoke when clicked.
  //
  // Returns the chosen button index {Number} if the buttons option was an array.
  confirm({message, detailedMessage, buttons} = {}) {
    let buttonLabels;
    if (_.isArray(buttons)) {
      buttonLabels = buttons;
    } else {
      buttonLabels = Object.keys(buttons || {});
    }

    const chosen = remote.dialog.showMessageBox(this.getCurrentWindow(), {
      type: 'info',
      message,
      detail: detailedMessage,
      buttons: buttonLabels,
    }
    );

    if (_.isArray(buttons)) {
      return chosen;
    }
    const callback = buttons[buttonLabels[chosen]];
    return callback ? callback() : undefined;
  }

  /*
  Section: Managing the Dev Tools
  */

  // Extended: Open the dev tools for the current window.
  openDevTools() {
    return ipcRenderer.send('call-webcontents-method', 'openDevTools');
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
    this.item = document.createElement("nylas-workspace");
    this.item.setAttribute("id", "sheet-container");
    this.item.setAttribute("class", "sheet-container");
    this.item.setAttribute("tabIndex", "-1");

    const React = require("react");
    const ReactDOM = require("react-dom");
    const SheetContainer = require('./sheet-container');
    ReactDOM.render(React.createElement(SheetContainer), this.item);
    return document.querySelector(this.workspaceViewParentSelector).appendChild(this.item);
  }

  deserializePackageStates() {
    this.packages.packageStates = this.savedState.packageStates || {};
    return delete this.savedState.packageStates;
  }

  loadConfig() {
    this.config.setSchema(null, {type: 'object', properties: _.clone(require('./config-schema').default)});
    return this.config.load();
  }

  watchThemes() {
    return this.themes.onDidChangeActiveThemes(() => {
      // Only reload stylesheets from non-theme packages
      for (const pack of Array.from(this.packages.getActivePackages())) {
        if (pack.getType() !== 'theme') {
          if (typeof pack.reloadStylesheets === 'function') {
            pack.reloadStylesheets();
          }
        }
      }
      return null;
    }
    );
  }

  exit(status) {
    const { app } = remote;
    app.emit('will-exit');
    return remote.process.exit(status);
  }

  showOpenDialog(options, callback) {
    return callback(remote.dialog.showOpenDialog(this.getCurrentWindow(), options));
  }

  showSaveDialog(options, callback) {
    if (options.title == null) { options.title = 'Save File'; }
    return callback(remote.dialog.showSaveDialog(this.getCurrentWindow(), options));
  }

  showErrorDialog(messageData, {showInMainWindow, detail} = {}) {
    let message;
    let title;
    if (_.isString(messageData) || _.isNumber(messageData)) {
      message = messageData;
      title = "Error";
    } else if (_.isObject(messageData)) {
      ({ message } = messageData);
      ({ title } = messageData);
    } else {
      throw new Error("Must pass a valid message to show dialog", message);
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
    return remote.dialog.showMessageBox(winToShow, {
      type: 'warning',
      buttons: ['Okay', 'Show Details'],
      message: title,
      detail: message,
    }, (buttonIndex) => {
      if (buttonIndex === 1) {
        const {Actions} = require('nylas-exports');
        const {CodeSnippet} = require('nylas-component-kit');
        Actions.openModal({
          component: CodeSnippet({intro: message, code: detail, className: 'error-details'}),
          height: 600,
          width: 800,
        });
      }
    });
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

  getUserInitScriptPath() {
    const initScriptPath = fs.resolve(this.getConfigDirPath(), 'init', ['js', 'coffee']);
    return initScriptPath != null ? initScriptPath : path.join(this.getConfigDirPath(), 'init.coffee');
  }

  requireUserInitScript() {
    const userInitScriptPath = this.getUserInitScriptPath();
    if (userInitScriptPath) {
      try {
        if (fs.isFileSync(userInitScriptPath)) { require(userInitScriptPath); }
      } catch (error) {
        console.log(error);
      }
    }
  }

  // Require the module with the given globals.
  //
  // The globals will be set on the `window` object and removed after the
  // require completes.
  //
  // * `id` The {String} module name or path.
  // * `globals` An optinal {Object} to set as globals during require.
  requireWithGlobals(id, globals = {}) {
    const existingGlobals = {};
    for (const key of globals) {
      const value = globals[key];
      existingGlobals[key] = window[key];
      window[key] = value;
    }

    require(id);

    return (() => {
      const result = [];
      for (const key of existingGlobals) {
        const value = existingGlobals[key];
        if (value === undefined) {
          result.push(delete window[key]);
        } else {
          result.push(window[key] = value);
        }
      }
      return result;
    })();
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
  // Also see logic in browser/NylasWindow::handleEvents where we listen
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
    if (this.inSpecMode()) { return; }
    this.actionBridge.registerGlobalActions(...args);
  }
}
NylasEnvConstructor.initClass();
