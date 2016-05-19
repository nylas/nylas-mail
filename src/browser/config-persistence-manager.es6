import path from 'path';
import pathWatcher from 'pathwatcher';
import fs from 'fs-plus';
import {BrowserWindow, dialog, app} from 'electron';

let _ = require('underscore');
_ = _.extend(_, require('../config-utils'));

export default class ConfigPersistenceManager {
  constructor({configDirPath, resourcePath} = {}) {
    this.configDirPath = configDirPath;
    this.resourcePath = resourcePath;

    this.userWantsToPreserveErrors = false
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
      const templateConfigPath = path.join(this.resourcePath, 'dot-nylas', 'config.json');
      const templateConfig = fs.readFileSync(templateConfigPath);
      fs.writeFileSync(this.configFilePath, templateConfig);
    }
  }

  load() {
    this.userWantsToPreserveErrors = false;

    try {
      const json = JSON.parse(fs.readFileSync(this.configFilePath)) || {};
      this.settings = json['*'];
      this.emitChangeEvent();
    } catch (error) {
      const message = `Failed to load "${path.basename(this.configFilePath)}"`;
      let detail = (error.location) ? error.stack : error.message;
      detail += `\n\nFix the formatting of ${this.configFilePath} to resolve this error, or reset your settings to continue using N1.`

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
        this.settings = {};
        this.emitChangeEvent();
      }
    }
  }

  loadSoon = () => {
    this._loadDebounced = this._loadDebounced || _.debounce(this.load, 100);
    this._loadDebounced();
  }

  observe() {
    try {
      this.watchSubscription = pathWatcher.watch(this.configFilePath, (eventType) => {
        if (eventType === 'change' && this.watchSubscription) {
          if (Date.now() - this.lastSaveTimstamp < 100) {
            return;
          }
          this.loadSoon();
        }
      })
    } catch (error) {
      this.notifyFailure("Configuration Error", `
        Unable to watch path: ${path.basename(this.configFilePath)}. Make sure you have permissions to
        ${this.configFilePath}. On linux there are currently problems with watch
        sizes.
      `);
    }
  }

  save = () => {
    if (this.userWantsToPreserveErrors) {
      return;
    }
    const allSettings = {'*': this.settings};
    const allSettingsJSON = JSON.stringify(allSettings, null, 2);
    this.lastSaveTimstamp = Date.now();
    fs.writeFileSync(this.configFilePath, allSettingsJSON);
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
