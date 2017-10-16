import { EventEmitter } from 'events';
import https from 'https';
import { shell } from 'electron';
import url from 'url';

export default class AutoupdateImplBase extends EventEmitter {
  supportsUpdates() {
    // If we're packaged into a Snapcraft distribution, we don't need
    // autoupdates within the app because they're handled transparently.
    if (process.env.SNAP) {
      return false;
    }
    return true;
  }

  /* Public: Set the feed URL where we retrieve update information. */
  setFeedURL(feedURL) {
    this.feedURL = feedURL;
    this.lastRetrievedUpdateURL = null;
  }

  emitError = error => {
    this.emit('error', error);
  };

  manuallyQueryUpdateServer(successCallback) {
    const feedHost = url.parse(this.feedURL).hostname;
    const feedPath = this.feedURL.split(feedHost).pop();

    // Hit the feed URL ourselves and see if an update is available.
    // On linux we can't autoupdate, but we can still show the "update available" bar.
    https
      .get({ host: feedHost, path: feedPath }, res => {
        console.log(`Manual update check (${feedHost}${feedPath}) returned ${res.statusCode}`);

        if (res.statusCode === 204) {
          successCallback(false);
          return;
        }

        let data = '';
        res.on('error', this.emitError);
        res.on('data', chunk => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (!json.url) {
              this.emitError(new Error(`Autoupdater response did not include URL: ${data}`));
              return;
            }
            successCallback(json);
          } catch (err) {
            this.emitError(err);
          }
        });
      })
      .on('error', this.emitError);
  }

  /* Public: Check for updates and emit events if an update is available. */
  checkForUpdates() {
    if (!this.feedURL) {
      return;
    }

    this.emit('checking-for-update');

    this.manuallyQueryUpdateServer(json => {
      if (!json) {
        this.emit('update-not-available');
        return;
      }
      this.lastRetrievedUpdateURL = json.url;
      this.emit('update-downloaded', null, 'manual-download', json.version);
    });
  }

  /* Public: Install the update. */
  quitAndInstall() {
    shell.openExternal(this.lastRetrievedUpdateURL || 'https://getmailspring.com/download');
  }
}
