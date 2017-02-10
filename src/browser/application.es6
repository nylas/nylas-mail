/* eslint global-require: "off" */

import {BrowserWindow, Menu, app, ipcMain, dialog} from 'electron';

import fs from 'fs-plus';
import url from 'url';
import path from 'path';
import proc from 'child_process'
import {EventEmitter} from 'events';

import WindowManager from './window-manager';
import FileListCache from './file-list-cache';
import DatabaseReader from './database-reader';
import ConfigMigrator from './config-migrator';
import ApplicationMenu from './application-menu';
import AutoUpdateManager from './auto-update-manager';
import SystemTrayManager from './system-tray-manager';
import PerformanceMonitor from './performance-monitor'
import DefaultClientHelper from '../default-client-helper';
import NylasProtocolHandler from './nylas-protocol-handler';
import PackageMigrationManager from './package-migration-manager';
import ConfigPersistenceManager from './config-persistence-manager';

let clipboard = null;

// The application's singleton class.
//
export default class Application extends EventEmitter {
  async start(options) {
    const {resourcePath, configDirPath, version, devMode, specMode, safeMode} = options;

    // Normalize to make sure drive letter case is consistent on Windows
    this.resourcePath = path.normalize(resourcePath);
    this.configDirPath = configDirPath;
    this.version = version;
    this.devMode = devMode;
    this.specMode = specMode;
    this.safeMode = safeMode;

    this.fileListCache = new FileListCache();
    this.nylasProtocolHandler = new NylasProtocolHandler(this.resourcePath, this.safeMode);

    this.databaseReader = new DatabaseReader({configDirPath, specMode});
    await this.databaseReader.open();

    const Config = require('../config');
    const config = new Config();
    this.config = config;
    this.configPersistenceManager = new ConfigPersistenceManager({configDirPath, resourcePath});
    config.load();

    this.configMigrator = new ConfigMigrator(this.config, this.databaseReader);
    this.configMigrator.migrate()

    this.packageMigrationManager = new PackageMigrationManager({config, configDirPath, version})
    this.packageMigrationManager.migrate()

    let initializeInBackground = options.background;
    if (initializeInBackground === undefined) {
      initializeInBackground = false;
    }

    this.autoUpdateManager = new AutoUpdateManager(version, config, specMode, this.databaseReader);
    this.applicationMenu = new ApplicationMenu(version);
    this.windowManager = new WindowManager({
      resourcePath: this.resourcePath,
      configDirPath: this.configDirPath,
      config: this.config,
      devMode: this.devMode,
      specMode: this.specMode,
      safeMode: this.safeMode,
      initializeInBackground: initializeInBackground,
    });
    this.systemTrayManager = new SystemTrayManager(process.platform, this);
    this._databasePhase = 'setup';
    this.perf = new PerformanceMonitor()

    this.setupJavaScriptArguments();
    this.handleEvents();
    this.handleLaunchOptions(options);

    if (process.platform === 'linux') {
      const helper = new DefaultClientHelper();
      helper.registerForURLScheme('nylas');
    } else {
      app.setAsDefaultProtocolClient('nylas');
    }

    if (process.platform === 'darwin') {
      const addedToDock = config.get('addedToDock');
      const appPath = process.argv[0];
      if (!addedToDock && appPath.includes('/Applications/') && appPath.includes('.app/')) {
        proc.exec(`defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${appPath.split('.app/')[0]}.app/</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"`);
        config.set('addedToDock', true);
      }
    }
  }

  getMainWindow() {
    return this.windowManager.get(WindowManager.MAIN_WINDOW).browserWindow;
  }

  getAllWindowDimensions() {
    return this.windowManager.getAllWindowDimensions()
  }

  isQuitting() {
    return this.quitting;
  }

  // Opens a new window based on the options provided.
  handleLaunchOptions(options) {
    const {specMode, pathsToOpen, urlsToOpen} = options;

    if (specMode) {
      const {resourcePath, specDirectory, specFilePattern, logFile, showSpecsInWindow, jUnitXmlPath} = options;
      const exitWhenDone = true;
      this.runSpecs({exitWhenDone, showSpecsInWindow, resourcePath, specDirectory, specFilePattern, logFile, jUnitXmlPath});
      return;
    }

    this.openWindowsForTokenState();

    if ((pathsToOpen instanceof Array) && (pathsToOpen.length > 0)) {
      this.openComposerWithFiles(pathsToOpen);
    }
    if (urlsToOpen instanceof Array) {
      for (const urlToOpen of urlsToOpen) {
        this.openUrl(urlToOpen);
      }
    }
  }

  // On Windows, removing a file can fail if a process still has it open. When
  // we close windows and log out, we need to wait for these processes to completely
  // exit and then delete the file. It's hard to tell when this happens, so we just
  // retry the deletion a few times.
  deleteFileWithRetry(filePath, callback = () => {}, retries = 5) {
    const callbackWithRetry = (err) => {
      if (err && (err.message.indexOf('no such file') === -1)) {
        console.log(`File Error: ${err.message} - retrying in 150msec`);
        setTimeout(() => {
          this.deleteFileWithRetry(filePath, callback, retries - 1);
        }, 150);
      } else {
        callback(null);
      }
    }

    if (!fs.existsSync(filePath)) {
      callback(null);
      return
    }

    if (retries > 0) {
      fs.unlink(filePath, callbackWithRetry);
    } else {
      fs.unlink(filePath, callback);
    }
  }

  // Configures required javascript environment flags.
  setupJavaScriptArguments() {
    app.commandLine.appendSwitch('js-flags', '--harmony');
  }

  openWindowsForTokenState() {
    const accounts = this.config.get('nylas.accounts');
    const hasAccount = accounts && accounts.length > 0;
    const hasN1ID = this._getNylasId();

    if (hasAccount && hasN1ID) {
      this.windowManager.ensureWindow(WindowManager.MAIN_WINDOW);
      this.windowManager.ensureWindow(WindowManager.WORK_WINDOW);
    } else {
      this.windowManager.ensureWindow(WindowManager.ONBOARDING_WINDOW, {
        title: "Welcome to Nylas Mail",
      });
      this.windowManager.ensureWindow(WindowManager.WORK_WINDOW);
    }
  }

  _getNylasId() {
    const identity = this.databaseReader.getJSONBlob("NylasID") || {}
    return identity.id
  }

  _relaunchToInitialWindows = ({resetConfig, resetDatabase} = {}) => {
    // This will re-fetch the NylasID to update the feed url
    this.autoUpdateManager.updateFeedURL()
    this.setDatabasePhase('close');
    this.windowManager.destroyAllWindows();

    let fn = (callback) => callback()
    if (resetDatabase) {
      fn = this._deleteDatabase;
    }

    fn(() => {
      if (resetConfig) {
        this.config.set('nylas', null);
        this.config.set('edgehill', null);
      }
      this.setDatabasePhase('setup');
      this.openWindowsForTokenState();
    });
  }

  _deleteDatabase = (callback) => {
    this.deleteFileWithRetry(path.join(this.configDirPath, 'edgehill.db'), callback);
    this.deleteFileWithRetry(path.join(this.configDirPath, 'edgehill.db-wal'));
    this.deleteFileWithRetry(path.join(this.configDirPath, 'edgehill.db-shm'));
  }

  databasePhase() {
    return this._databasePhase;
  }

  setDatabasePhase(phase) {
    if (!['setup', 'ready', 'close'].includes(phase)) {
      throw new Error(`setDatabasePhase: ${phase} is invalid.`);
    }

    if (phase === this._databasePhase) {
      return;
    }

    this._databasePhase = phase;
    this.windowManager.sendToAllWindows("database-phase-change", {}, phase);
  }

  rebuildDatabase = () => {
    // We need to set a timeout so `rebuildDatabases` immediately returns.
    // If we don't immediately return the main window caller wants to wait
    // for this function to finish so it can get the return value via ipc.
    // Unfortunately since this function destroys the main window
    // immediately, an error will be thrown.
    setTimeout(() => {
      if (this._databasePhase === 'close') {
        return;
      }
      this.setDatabasePhase('close');
      this.windowManager.destroyAllWindows();
      this._deleteDatabase(() => {
        this.setDatabasePhase('setup');
        this.openWindowsForTokenState();
      });
    }, 0);
  }

  // Registers basic application commands, non-idempotent.
  // Note: If these events are triggered while an application window is open, the window
  // needs to manually bubble them up to the Application instance via IPC or they won't be
  // handled. This happens in workspace-element.coffee
  handleEvents() {
    this.on('application:run-all-specs', () => {
      const win = this.windowManager.focusedWindow();
      this.runSpecs({
        exitWhenDone: false,
        showSpecsInWindow: true,
        resourcePath: this.resourcePath,
        safeMode: win && win.safeMode,
      });
    });

    this.on('application:run-package-specs', () => {
      dialog.showOpenDialog({
        title: 'Choose a Package Directory',
        defaultPath: this.configDirPath,
        buttonLabel: 'Choose',
        properties: ['openDirectory'],
      }, (filenames) => {
        if (!filenames || filenames.length === 0) {
          return;
        }
        this.runSpecs({
          exitWhenDone: false,
          showSpecsInWindow: true,
          resourcePath: this.resourcePath,
          specDirectory: filenames[0],
        });
      });
    });

    this.on('application:relaunch-to-initial-windows', this._relaunchToInitialWindows);

    this.on('application:onIdentityChanged', () => {
      this.autoUpdateManager.updateFeedURL()
    });

    this.on('application:quit', () => {
      app.quit()
    });

    this.on('application:inspect', ({x, y, nylasWindow}) => {
      const win = nylasWindow || this.windowManager.focusedWindow();
      if (!win) {
        return;
      }
      win.browserWindow.inspectElement(x, y);
    });

    this.on('application:add-account', ({existingAccount, accountType} = {}) => {
      const onboarding = this.windowManager.get(WindowManager.ONBOARDING_WINDOW);
      if (onboarding) {
        if (onboarding.browserWindow.webContents) {
          onboarding.browserWindow.webContents.send('set-account-type', accountType)
        }
        onboarding.show();
        onboarding.focus();
      } else {
        this.windowManager.ensureWindow(WindowManager.ONBOARDING_WINDOW, {
          title: "Add an Account",
          windowProps: { addingAccount: true, existingAccount, accountType },
        });
      }
    });

    this.on('application:new-message', () => {
      const main = this.windowManager.get(WindowManager.MAIN_WINDOW);
      if (main) { main.sendMessage('new-message') }
    });

    this.on('application:view-help', () => {
      const helpUrl = 'https://support.nylas.com/hc/en-us/categories/200419318-Help-for-N1-users';
      require('electron').shell.openExternal(helpUrl);
    });

    this.on('application:open-preferences', () => {
      const main = this.windowManager.get(WindowManager.MAIN_WINDOW);
      if (main) { main.sendMessage('open-preferences') }
    });

    this.on('application:show-main-window', () => {
      this.openWindowsForTokenState();
    });

    this.on('application:check-for-update', () => {
      this.autoUpdateManager.check();
    });

    this.on('application:install-update', () => {
      this.quitting = true;
      this.windowManager.cleanupBeforeAppQuit();
      this.autoUpdateManager.install();
    });

    this.on('application:toggle-dev', () => {
      let args = process.argv.slice(1);
      if (args.includes('--dev')) {
        args = args.filter(a => a !== '--dev');
      } else {
        args.push('--dev')
      }
      app.relaunch({args});
      app.quit();
    });

    if (process.platform === 'darwin') {
      this.on('application:about', () => {
        Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
      });
      this.on('application:bring-all-windows-to-front', () => {
        Menu.sendActionToFirstResponder('arrangeInFront:')
      });
      this.on('application:hide', () => {
        Menu.sendActionToFirstResponder('hide:')
      });
      this.on('application:hide-other-applications', () => {
        Menu.sendActionToFirstResponder('hideOtherApplications:')
      });
      this.on('application:minimize', () => {
        Menu.sendActionToFirstResponder('performMiniaturize:')
      });
      this.on('application:unhide-all-applications', () => {
        Menu.sendActionToFirstResponder('unhideAllApplications:')
      });
      this.on('application:zoom', () => {
        Menu.sendActionToFirstResponder('zoom:')
      });
    } else {
      this.on('application:minimize', () => {
        const win = this.windowManager.focusedWindow();
        if (win) { win.minimize() }
      });
      this.on('application:zoom', () => {
        const win = this.windowManager.focusedWindow();
        if (win) { win.maximize() }
      });
    }

    app.on('window-all-closed', () => {
      this.windowManager.quitWinLinuxIfNoWindows()
    });

    // Called before the app tries to close any windows.
    app.on('before-quit', () => {
      // Allow the main window to be closed.
      this.quitting = true;
      // Destroy hot windows so that they can't block the app from quitting.
      // (Electron will wait for them to finish loading before quitting.)
      this.windowManager.cleanupBeforeAppQuit();
      this.systemTrayManager.destroyTray();
    });

    // Called after the app has closed all windows.
    app.on('will-quit', () => {
      this.setDatabasePhase('close');
    });

    app.on('will-exit', () => {
      this.setDatabasePhase('close');
    });

    app.on('open-file', (event, pathToOpen) => {
      this.openComposerWithFiles([pathToOpen]);
      event.preventDefault();
    });

    app.on('open-url', (event, urlToOpen) => {
      this.openUrl(urlToOpen);
      event.preventDefault();
    });

    // System Tray
    ipcMain.on('update-system-tray', (event, ...args) => {
      this.systemTrayManager.updateTraySettings(...args);
    });

    ipcMain.on('set-badge-value', (event, value) => {
      if (app.dock && app.dock.setBadge) {
        app.dock.setBadge(value);
      } else if (app.setBadgeCount) {
        app.setBadgeCount(value.length ? (value.replace("+", "") / 1) : 0);
      }
    });

    ipcMain.on('new-window', (event, options) => {
      const win = options.windowKey ? this.windowManager.get(options.windowKey) : null;
      if (win) {
        win.show();
        win.focus();
      } else {
        this.windowManager.newWindow(options);
      }
    });

    ipcMain.on('inline-style-parse', (event, {html, key}) => {
      const juice = require('juice');
      let out = null;
      try {
        out = juice(html);
      } catch (e) {
        // If the juicer fails (because of malformed CSS or some other
        // reason), then just return the body. We will still push it
        // through the HTML sanitizer which will strip the style tags. Oh
        // well.
        out = html
      }
      // win = BrowserWindow.fromWebContents(event.sender)
      event.sender.send('inline-styles-result', {html: out, key});
    });

    app.on('activate', (event, hasVisibleWindows) => {
      if (!hasVisibleWindows) {
        this.openWindowsForTokenState();
      }
      event.preventDefault();
    });

    ipcMain.on('update-application-menu', (event, template, keystrokesByCommand) => {
      const win = BrowserWindow.fromWebContents(event.sender);
      this.applicationMenu.update(win, template, keystrokesByCommand);
    });

    ipcMain.on('command', (event, command, ...args) => {
      this.emit(command, ...args);
    });

    ipcMain.on('window-command', (event, command, ...args) => {
      const win = BrowserWindow.fromWebContents(event.sender);
      win.emit(command, ...args);
    });

    ipcMain.on('call-window-method', (event, method, ...args) => {
      const win = BrowserWindow.fromWebContents(event.sender);
      if (!win[method]) {
        console.error(`Method ${method} does not exist on BrowserWindow!`);
      }
      win[method](...args)
    });

    ipcMain.on('call-devtools-webcontents-method', (event, method, ...args) => {
      // If devtools aren't open the `webContents::devToolsWebContents` will be null
      if (event.sender.devToolsWebContents) {
        event.sender.devToolsWebContents[method](...args);
      }
    });

    ipcMain.on('call-webcontents-method', (event, method, ...args) => {
      if (!event.sender[method]) {
        console.error(`Method ${method} does not exist on WebContents!`);
      }
      event.sender[method](...args);
    });

    ipcMain.on('action-bridge-rebroadcast-to-all', (event, ...args) => {
      const win = BrowserWindow.fromWebContents(event.sender)
      this.windowManager.sendToAllWindows('action-bridge-message', {except: win}, ...args)
    });

    ipcMain.on('action-bridge-rebroadcast-to-work', (event, ...args) => {
      const workWindow = this.windowManager.get(WindowManager.WORK_WINDOW)
      if (!workWindow || !workWindow.browserWindow.webContents) {
        return;
      }
      if (BrowserWindow.fromWebContents(event.sender) === workWindow) {
        return;
      }
      workWindow.browserWindow.webContents.send('action-bridge-message', ...args);
    });

    ipcMain.on('write-text-to-selection-clipboard', (event, selectedText) => {
      clipboard = require('electron').clipboard;
      clipboard.writeText(selectedText, 'selection');
    });

    ipcMain.on('account-setup-successful', () => {
      this.windowManager.ensureWindow(WindowManager.MAIN_WINDOW);
      this.windowManager.ensureWindow(WindowManager.WORK_WINDOW);
      const onboarding = this.windowManager.get(WindowManager.ONBOARDING_WINDOW);
      if (onboarding) {
        onboarding.close();
      }
    });

    ipcMain.on('new-account-added', () => {
      this.windowManager.ensureWindow(WindowManager.WORK_WINDOW)
    });

    ipcMain.on('run-in-window', (event, params) => {
      const sourceWindow = BrowserWindow.fromWebContents(event.sender);
      this._sourceWindows = this._sourceWindows || {};
      this._sourceWindows[params.taskId] = sourceWindow

      const targetWindowKey = {
        work: WindowManager.WORK_WINDOW,
        main: WindowManager.MAIN_WINDOW,
      }[params.window];
      if (!targetWindowKey) {
        throw new Error("We don't support running in that window");
      }

      const targetWindow = this.windowManager.get(targetWindowKey);
      if (!targetWindow || !targetWindow.browserWindow.webContents) {
        return;
      }
      targetWindow.browserWindow.webContents.send('run-in-window', params);
    });

    ipcMain.on('remote-run-results', (event, params) => {
      const sourceWindow = this._sourceWindows[params.taskId];
      sourceWindow.webContents.send('remote-run-results', params);
      delete this._sourceWindows[params.taskId];
    });

    ipcMain.on("report-error", (event, params = {}) => {
      try {
        const errorParams = JSON.parse(params.errorJSON || "{}");
        const extra = JSON.parse(params.extra || "{}");
        let err = new Error();
        err = Object.assign(err, errorParams);
        global.errorLogger.reportError(err, extra)
      } catch (parseError) {
        console.error(parseError)
        global.errorLogger.reportError(parseError, {})
      }
      event.returnValue = true
    })

    ipcMain.on("move-to-applications", () => {
      if (process.platform !== "darwin") {
        return;
      }
      const re = /(^.*?\.app)/i;
      const appPath = (re.exec(process.argv[0]) || [])[0];
      if (!appPath) {
        throw new Error(`Couldn't find .app in launch path: ${process.argv[0]}`)
      }
      let appName = appPath.split("/");
      appName = appName[appName.length - 1]
      if (!appName) {
        throw new Error(`Couldn't find .app in app path: ${appPath}`)
      }
      const escapedName = this._escapeShell(appName);
      const escapedPath = this._escapeShell(appPath);

      if (!escapedName || escapedName.trim().length === 0) {
        throw new Error(`escapedName is invalid: ${escapedName}`)
      }

      // We separate the commands with a `;` instead of `&&` so in case the
      // mv fails, the open will still run.
      // We need the sleep to let the first app fully finish quitting.
      // Otherwise it'll attempt to re-open the existing app (the one in
      // the process of quitting)
      const newAppDest = `/Applications/${escapedName}`
      let move = `mv`
      try { fs.accessSync(appPath, fs.W_OK) } catch (e) { move = `cp -r` }
      const cmd = `rm -rf ${newAppDest}; ${move} ${escapedPath} ${newAppDest}; sleep 0.5; open ${newAppDest}`;
      app.once('will-quit', () => {
        // We need to use `exec` since that will start a new shell process and
        // allow us to kill this one.
        proc.exec(cmd)
      })
      app.quit()
    })
  }

  _escapeShell(cmd) {
    return cmd.replace(/(["\s'$`\\])/g, '\\$1');
  }

  // Public: Executes the given command.
  //
  // If it isn't handled globally, delegate to the currently focused window.
  // If there is no focused window (all the windows of the app are hidden),
  // fire the command to the main window. (This ensures that `application:`
  // commands, like Cmd-N work when no windows are visible.)
  //
  // command - The string representing the command.
  // args - The optional arguments to pass along.
  sendCommand(command, ...args) {
    if (this.emit(command, ...args)) {
      return;
    }
    const focusedWindow = this.windowManager.focusedWindow()
    if (focusedWindow) {
      focusedWindow.sendCommand(command, ...args);
    } else {
      if (this.sendCommandToFirstResponder(command)) {
        return;
      }

      const focusedBrowserWindow = BrowserWindow.getFocusedWindow()
      const mainWindow = this.windowManager.get(WindowManager.MAIN_WINDOW)
      if (focusedBrowserWindow) {
        switch (command) {
          case 'window:reload':
            focusedBrowserWindow.reload();
            break;
          case 'window:toggle-dev-tools':
            focusedBrowserWindow.toggleDevTools();
            break;
          case 'window:close':
            focusedBrowserWindow.close();
            break;
          default:
            break;
        }
      } else if (mainWindow) {
        mainWindow.sendCommand(command, ...args);
      }
    }
  }

  // Public: Executes the given command on the given window.
  //
  // command - The string representing the command.
  // nylasWindow - The {NylasWindow} to send the command to.
  // args - The optional arguments to pass along.
  sendCommandToWindow = (command, nylasWindow, ...args) => {
    console.log('sendCommandToWindow');
    console.log(command);
    if (this.emit(command, ...args)) {
      return;
    }
    if (nylasWindow) {
      nylasWindow.sendCommand(command, ...args);
    } else {
      this.sendCommandToFirstResponder(command);
    }
  };

  // Translates the command into OS X action and sends it to application's first
  // responder.
  sendCommandToFirstResponder = (command) => {
    if (process.platform !== 'darwin') {
      return false;
    }

    const commandsToActions = {
      'core:undo': 'undo:',
      'core:redo': 'redo:',
      'core:copy': 'copy:',
      'core:cut': 'cut:',
      'core:paste': 'paste:',
      'core:select-all': 'selectAll:',
    };

    if (commandsToActions[command]) {
      Menu.sendActionToFirstResponder(commandsToActions[command]);
      return true;
    }
    return false;
  };

  // Open a mailto:// url.
  //
  openUrl(urlToOpen) {
    const parts = url.parse(urlToOpen);
    const main = this.windowManager.get(WindowManager.MAIN_WINDOW);

    if (!main) {
      console.log(`Ignoring URL - main window is not available, user may not be authed.`);
      return;
    }

    if (parts.protocol === 'mailto:') {
      main.sendMessage('mailto', urlToOpen);
    } else if (parts.protocol === 'nylas:') {
      // if (parts.host === 'calendar') {
      //   this.openCalendarURL(parts.path);
      if (parts.host === 'plugins') {
        main.sendMessage('changePluginStateFromUrl', urlToOpen);
      } else {
        main.sendMessage('openExternalThread', urlToOpen);
      }
    } else {
      console.log(`Ignoring unknown URL type: ${urlToOpen}`);
    }
  }

  // openCalendarURL(command) {
  //   if (command === '/open') {
  //     this.windowManager.ensureWindow(WindowManager.CALENDAR_WINDOW, {
  //       windowKey: WindowManager.CALENDAR_WINDOW,
  //       windowType: WindowManager.CALENDAR_WINDOW,
  //       title: "Calendar",
  //       hidden: false,
  //     });
  //   } else if (command === '/close') {
  //     const win = this.windowManager.get(WindowManager.CALENDAR_WINDOW);
  //     if (win) { win.hide(); }
  //   }
  // }

  openComposerWithFiles(pathsToOpen) {
    const main = this.windowManager.get(WindowManager.MAIN_WINDOW);
    if (main) { main.sendMessage('mailfiles', pathsToOpen) }
  }

  // Opens up a new {NylasWindow} to run specs within.
  //
  // options -
  //   :exitWhenDone - A Boolean that, if true, will close the window upon
  //                   completion and exit the app with the status code of
  //                   1 if the specs failed and 0 if they passed.
  //   :showSpecsInWindow - A Boolean that, if true, will run specs in a
  //                        window
  //   :resourcePath - The path to include specs from.
  //   :specPath - The directory to load specs from.
  //   :safeMode - A Boolean that, if true, won't run specs from ~/.nylas-mail/packages
  //               and ~/.nylas-mail/dev/packages, defaults to false.
  //   :jUnitXmlPath - The path to output jUnit XML reports to, if desired.
  runSpecs(specWindowOptionsArg) {
    const specWindowOptions = specWindowOptionsArg;
    let {resourcePath} = specWindowOptions;
    if ((resourcePath !== this.resourcePath) && (!fs.existsSync(resourcePath))) {
      resourcePath = this.resourcePath;
    }

    let bootstrapScript = null;
    try {
      bootstrapScript = require.resolve(path.resolve(this.resourcePath, 'spec', 'n1-spec-runner', 'spec-bootstrap'));
    } catch (error) {
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'n1-spec-runner', 'spec-bootstrap'));
    }

    // Important: Use .nylas-spec instead of .nylas-mail to avoid overwriting the
    // user's real email config!
    const configDirPath = path.join(app.getPath('home'), '.nylas-spec');

    specWindowOptions.resourcePath = resourcePath;
    specWindowOptions.configDirPath = configDirPath;
    specWindowOptions.bootstrapScript = bootstrapScript;

    this.windowManager.ensureWindow(WindowManager.SPEC_WINDOW, specWindowOptions);
  }
}
