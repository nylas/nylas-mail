import path from 'path';
import pathWatcher from 'pathwatcher';
import fs from 'fs-plus';
import {BrowserWindow, dialog, app} from 'electron';
import {atomicWriteFileSync} from '../fs-utils'

let _ = require('underscore');
_ = _.extend(_, require('../config-utils'));

const RETRY_SAVES = 3


export default class ConfigPersistenceManager {
  constructor({configDirPath, resourcePath} = {}) {
    this.configDirPath = configDirPath;
    this.resourcePath = resourcePath;

    this.userWantsToPreserveErrors = false
    this.saveRetries = 0
    this.configFilePath = path.join(this.configDirPath, 'config.json')
    this.settings = {};

    this.initializeConfigDirectory();
    this.load();
    this.observe();
  }

  initializeConfigDirectory() {
    if (!fs.existsSync(this.configDirPath)) {
      fs.makeTreeSync(this.configDirPath);
      const templateConfigDirPath = path.join(this.resourcePath, 'dot-nylas');
      fs.copySync(templateConfigDirPath, this.configDirPath);
    }

    if (!fs.existsSync(this.configFilePath)) {
      this.writeTemplateConfigFile();
    }
  }

  writeTemplateConfigFile() {
    const templateConfigPath = path.join(this.resourcePath, 'dot-nylas', 'config.json');
    const templateConfig = fs.readFileSync(templateConfigPath);
    fs.writeFileSync(this.configFilePath, templateConfig);
  }

  load() {
    this.userWantsToPreserveErrors = false;

    try {
      const json = JSON.parse(fs.readFileSync(this.configFilePath)) || {};
      this.settings = json['*'];
      this.emitChangeEvent();
    } catch (error) {
      global.errorLogger.reportError(error, {event: 'Failed to load config.json'})
      const message = `Failed to load "${path.basename(this.configFilePath)}"`;
      let detail = (error.location) ? error.stack : error.message;

      if (error instanceof SyntaxError) {
        detail += `\n\nThe file ${this.configFilePath} has incorrect JSON formatting or is empty. Fix the formatting to resolve this error, or reset your settings to continue using N1.`
      } else {
        detail += `\n\nWe were unable to read the file ${this.configFilePath}. Make sure you have permissions to access this file, and check that the file is not open or being edited and try again.`
      }

      const clickedIndex = dialog.showMessageBox({
        type: 'error',
        message,
        detail,
        buttons: ['Quit', 'Try Again', 'Reset Configuration'],
      });

      if (clickedIndex === 0) {
        this.userWantsToPreserveErrors = true;
        app.quit();
      } else if (clickedIndex === 1) {
        this.load();
      } else {
        if (fs.existsSync(this.configFilePath)) {
          fs.unlinkSync(this.configFilePath);
        }
        this.writeTemplateConfigFile();
        this.load();
      }
    }
  }

  loadSoon = () => {
    this._loadDebounced = this._loadDebounced || _.debounce(this.load, 100);
    this._loadDebounced();
  }

  observe() {
    // watch the config file for edits. This observer needs to be
    // replaced if the config file is deleted.
    let watcher = null;
    const watchCurrentConfigFile = () => {
      try {
        if (watcher) {
          watcher.close();
        }
        watcher = pathWatcher.watch(this.configFilePath, (e) => {
          if (e === 'change') {
            this.loadSoon();
          }
        });
      } catch (error) {
        this.observeErrorOccurred(error);
      }
    }
    watchCurrentConfigFile();

    // watch the config directory (non-recursive) to catch the config file
    // being deleted and replaced or atomically edited.
    try {
      let lastctime = null;
      pathWatcher.watch(this.configDirPath, () => {
        fs.stat(this.configFilePath, (err, stats) => {
          if (err) { return; }

          const ctime = stats.ctime.getTime();
          if (ctime !== lastctime) {
            if (Math.abs(ctime - this.lastSaveTimestamp) > 2000) {
              this.loadSoon();
            }
            watchCurrentConfigFile();
            lastctime = ctime;
          }
        });
      })
    } catch (error) {
      this.observeErrorOccurred(error);
    }
  }

  observeErrorOccurred = (error) => {
    global.errorLogger.reportError(error)
    dialog.showMessageBox({
      type: 'error',
      message: 'Configuration Error',
      detail: `
      Unable to watch path: ${path.basename(this.configFilePath)}. Make sure you have permissions to
      ${this.configFilePath}. On linux there are currently problems with watch
      sizes.
      `,
      buttons: ['Okay'],
    })
  }

  save = () => {
    if (this.userWantsToPreserveErrors) {
      return;
    }
    const allSettings = {'*': this.settings};
    const allSettingsJSON = JSON.stringify(allSettings, null, 2);
    this.lastSaveTimestamp = Date.now();

    try {
      atomicWriteFileSync(this.configFilePath, allSettingsJSON)
      this.saveRetries = 0
    } catch (error) {
      if (this.saveRetries >= RETRY_SAVES) {
        global.errorLogger.reportError(error, {event: 'Failed to save config.json'})
        const clickedIndex = dialog.showMessageBox({
          type: 'error',
          message: `Failed to save "${path.basename(this.configFilePath)}"`,
          detail: `\n\nWe were unable to save the file ${this.configFilePath}. Make sure you have permissions to access this file, and check that the file is not open or being edited and try again.`,
          buttons: ['Okay', 'Try again'],
        })
        this.saveRetries = 0
        if (clickedIndex === 1) {
          this.saveSoon()
        }
      } else {
        this.saveRetries++
        this.saveSoon()
      }
    }
  }

  saveSoon = () => {
    this._saveThrottled = this._saveThrottled || _.throttle(this.save, 100);
    this._saveThrottled();
  }

  getRawValuesString = () => {
    return JSON.stringify(this.settings);
  }

  setRawValue = (keyPath, value, sourceWebcontentsId) => {
    if (keyPath) {
      _.setValueForKeyPath(this.settings, keyPath, value);
    } else {
      this.settings = value;
    }

    this.emitChangeEvent({sourceWebcontentsId});
    this.saveSoon();
    return null;
  }

  emitChangeEvent = ({sourceWebcontentsId} = {}) => {
    global.application.config.updateSettings(this.settings);

    BrowserWindow.getAllWindows().forEach((win) => {
      if ((win.webContents) && (win.webContents.getId() !== sourceWebcontentsId)) {
        win.webContents.send('on-config-reloaded', this.settings);
      }
    });
  }
}
