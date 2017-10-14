/* eslint global-require: 0*/
import { dialog } from 'electron';
import { EventEmitter } from 'events';
import path from 'path';
import fs from 'fs';

let autoUpdater = null;

const IdleState = 'idle';
const CheckingState = 'checking';
const DownloadingState = 'downloading';
const UpdateAvailableState = 'update-available';
const NoUpdateAvailableState = 'no-update-available';
const UnsupportedState = 'unsupported';
const ErrorState = 'error';
const preferredChannel = 'stable';

export default class AutoUpdateManager extends EventEmitter {
  constructor(version, config, specMode) {
    super();

    this.state = IdleState;
    this.version = version;
    this.config = config;
    this.specMode = specMode;
    this.preferredChannel = preferredChannel;

    this.updateFeedURL();
    this.config.onDidChange('identity.id', this.updateFeedURL);

    setTimeout(() => this.setupAutoUpdater(), 0);
  }

  updateFeedURL = () => {
    const params = {
      platform: process.platform,
      arch: process.arch,
      version: this.version,
      id: this.config.get('identity.id') || 'anonymous',
      channel: this.preferredChannel,
    };

    let host = `updates.getmailspring.com`;
    if (this.config.get('env') === 'staging') {
      host = `updates-staging.getmailspring.com`;
    }

    this.feedURL = `https://${host}/check/${params.platform}/${params.arch}/${params.version}/${params.id}/${params.channel}`;
    if (autoUpdater) {
      autoUpdater.setFeedURL(this.feedURL);
    }
  };

  setupAutoUpdater() {
    if (process.platform === 'win32') {
      const Impl = require('./autoupdate-impl-win32').default;
      autoUpdater = new Impl();
    } else if (process.platform === 'linux') {
      const Impl = require('./autoupdate-impl-base').default;
      autoUpdater = new Impl();
    } else {
      autoUpdater = require('electron').autoUpdater;
    }

    autoUpdater.on('error', (message) => {
      if (this.specMode) return;
      console.error(`Error Downloading Update: ${message}`);
      this.setState(ErrorState);
    });

    autoUpdater.setFeedURL(this.feedURL);

    autoUpdater.on('checking-for-update', () => {
      this.setState(CheckingState);
    });

    autoUpdater.on('update-not-available', () => {
      this.setState(NoUpdateAvailableState);
    });

    autoUpdater.on('update-available', () => {
      this.setState(DownloadingState);
    });

    autoUpdater.on('update-downloaded', (event, releaseNotes, releaseVersion) => {
      this.releaseNotes = releaseNotes;
      this.releaseVersion = releaseVersion;
      this.setState(UpdateAvailableState);
      this.emitUpdateAvailableEvent();
    });

    if (autoUpdater.supportsUpdates && !autoUpdater.supportsUpdates()) {
      this.setState(UnsupportedState);
      return;
    }

    //check immediately at startup
    this.check({ hidePopups: true });

    //check every 30 minutes
    setInterval(() => {
      if ([UpdateAvailableState, UnsupportedState].includes(this.state)) {
        console.log('Skipping update check... update ready to install, or updater unavailable.');
        return;
      }
      this.check({ hidePopups: true });
    }, 1000 * 60 * 30);
  }

  emitUpdateAvailableEvent() {
    if (!this.releaseVersion) {
      return;
    }
    global.application.windowManager.sendToAllWindows(
      'update-available',
      {},
      this.getReleaseDetails()
    );
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

  getReleaseDetails() {
    return {
      releaseVersion: this.releaseVersion,
      releaseNotes: this.releaseNotes,
    };
  }

  check({ hidePopups } = {}) {
    this.updateFeedURL();
    if (!hidePopups) {
      autoUpdater.once('update-not-available', this.onUpdateNotAvailable);
      autoUpdater.once('error', this.onUpdateError);
    }
    autoUpdater.checkForUpdates();
  }

  install() {
    autoUpdater.quitAndInstall();
  }

  iconURL() {
    const url = path.join(process.resourcesPath, 'app', 'mailspring.png');
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
      detail: `You're running the latest version of Mailspring (${this.version}).`,
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
  };
}
