/* eslint global-require: 0*/
import {dialog} from 'electron';
import {EventEmitter} from 'events';
import path from 'path';
import fs from 'fs';
import qs from 'querystring';

let autoUpdater = null;

const IdleState = 'idle';
const CheckingState = 'checking';
const DownloadingState = 'downloading';
const UpdateAvailableState = 'update-available';
const NoUpdateAvailableState = 'no-update-available';
const UnsupportedState = 'unsupported';
const ErrorState = 'error';
const preferredChannel = 'nylas-mail'

export default class AutoUpdateManager extends EventEmitter {

  constructor(version, config, specMode, databaseReader) {
    super();

    this.state = IdleState;
    this.version = version;
    this.config = config;
    this.databaseReader = databaseReader
    this.specMode = specMode;
    this.preferredChannel = preferredChannel;

    this.updateFeedURL();

    setTimeout(() => this.setupAutoUpdater(), 0);
  }

  parameters = () => {
    let updaterId = (this.databaseReader.getJSONBlob("NylasID") || {}).id
    if (!updaterId) {
      updaterId = "anonymous";
    }

    const emails = [];
    const accounts = this.config.get('nylas.accounts') || [];
    for (const account of accounts) {
      if (account.email_address) {
        emails.push(encodeURIComponent(account.email_address));
      }
    }
    const updaterEmails = emails.join(',');

    return {
      platform: process.platform,
      arch: process.arch,
      version: this.version,
      id: updaterId,
      emails: updaterEmails,
      preferredChannel: this.preferredChannel,
    };
  }

  updateFeedURL = () => {
    const params = this.parameters();

    let host = `edgehill.nylas.com`;
    if (this.config.get('env') === 'staging') {
      host = `edgehill-staging.nylas.com`;
    }

    if (process.platform === 'win32') {
      // Squirrel for Windows can't handle query params
      // https://github.com/Squirrel/Squirrel.Windows/issues/132
      this.feedURL = `https://${host}/update-check/win32/${params.arch}/${params.version}/${params.id}/${params.emails}`
    } else {
      this.feedURL = `https://${host}/update-check?${qs.stringify(params)}`;
    }

    if (autoUpdater) {
      autoUpdater.setFeedURL(this.feedURL)
    }
  }

  setupAutoUpdater() {
    if (process.platform === 'win32') {
      autoUpdater = require('./windows-updater-squirrel-adapter');
    } else if (process.platform === 'linux') {
      autoUpdater = require('./linux-updater-adapter').default;
    } else {
      autoUpdater = require('electron').autoUpdater;
    }

    autoUpdater.on('error', (event, message) => {
      if (this.specMode) return;
      console.error(`Error Downloading Update: ${message}`);
      this.setState(ErrorState);
    });

    autoUpdater.setFeedURL(this.feedURL);

    autoUpdater.on('checking-for-update', () => {
      this.setState(CheckingState)
    });

    autoUpdater.on('update-not-available', () => {
      this.setState(NoUpdateAvailableState)
    });

    autoUpdater.on('update-available', () => {
      this.setState(DownloadingState)
    });

    autoUpdater.on('update-downloaded', (event, releaseNotes, releaseVersion) => {
      this.releaseNotes = releaseNotes;
      this.releaseVersion = releaseVersion;
      this.setState(UpdateAvailableState);
      this.emitUpdateAvailableEvent();
    });

    this.check({hidePopups: true});
    setInterval(() => {
      if ([UpdateAvailableState, UnsupportedState].includes(this.state)) {
        console.log("Skipping update check... update ready to install, or updater unavailable.");
        return;
      }
      this.check({hidePopups: true});
    }, 1000 * 60 * 30);

    if (autoUpdater.supportsUpdates && !autoUpdater.supportsUpdates()) {
      this.setState(UnsupportedState);
    }
  }

  emitUpdateAvailableEvent() {
    if (!this.releaseVersion) {
      return;
    }
    global.application.windowManager.sendToAllWindows("update-available", {}, {
      releaseVersion: this.releaseVersion,
      releaseNotes: this.releaseNotes,
    });
  }

  setState(state) {
    if (this.state === state) {
      return;
    }
    this.state = state;
    this.emit('state-changed', this.state);
  }

  getState() {
    return this.state;
  }

  check({hidePopups} = {}) {
    this.updateFeedURL();
    if (!hidePopups) {
      autoUpdater.once('update-not-available', this.onUpdateNotAvailable);
      autoUpdater.once('error', this.onUpdateError);
    }
    if (process.platform === "win32") {
      // There's no separate "checking" stage on Windows. It also
      // "installs" as soon as it downloads. You just need to restart to
      // launch the updated app.
      autoUpdater.downloadAndInstallUpdate();
    } else {
      autoUpdater.checkForUpdates();
    }
  }

  install() {
    if (process.platform === "win32") {
      // On windows the update has already been "installed" and shortcuts
      // already updated. You just need to restart the app to load the new
      // version.
      autoUpdater.restartN1();
    } else {
      autoUpdater.quitAndInstall();
    }
  }

  iconURL() {
    const url = path.join(process.resourcesPath, 'app', 'nylas.png');
    if (!fs.existsSync(url)) {
      return undefined;
    }
    return url;
  }

  onUpdateNotAvailable = () => {
    autoUpdater.removeListener('error', this.onUpdateError);
    dialog.showMessageBox({
      type: 'info',
      buttons: ['OK'],
      icon: this.iconURL(),
      message: 'No update available.',
      title: 'No Update Available',
      detail: `You're running the latest version of Nylas Mail (${this.version}).`,
    });
  };

  onUpdateError = (event, message) => {
    autoUpdater.removeListener('update-not-available', this.onUpdateNotAvailable);
    dialog.showMessageBox({
      type: 'warning',
      buttons: ['OK'],
      icon: this.iconURL(),
      message: 'There was an error checking for updates.',
      title: 'Update Error',
      detail: message,
    });
  }
}
