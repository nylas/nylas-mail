import AutoupdateImplBase from './autoupdate-impl-base';
import WindowsUpdater from './windows-updater';

export default class AutoupdateImplWin32 extends AutoupdateImplBase {
  supportsUpdates() {
    return WindowsUpdater.existsSync();
  }

  checkForUpdates() {
    if (!this.feedURL) {
      return;
    }
    if (!WindowsUpdater.existsSync()) {
      console.error('SquirrelUpdate does not exist');
      return;
    }

    this.emit('checking-for-update');

    this.manuallyQueryUpdateServer(json => {
      if (!json) {
        this.emit('update-not-available');
        return;
      }

      this.emit('update-available');
      this.lastRetrievedUpdateURL = json.url;

      WindowsUpdater.spawn(['--update', json.url], (error, stdout) => {
        if (error) {
          this.emitError(error);
          return;
        }
        this.emit('update-downloaded', {}, 'A new version is available!', json.version);
      });
    });
  }

  quitAndInstall() {
    WindowsUpdater.restartMailspring(require('electron').app);
  }
}
