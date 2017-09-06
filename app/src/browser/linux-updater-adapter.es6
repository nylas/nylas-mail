import {EventEmitter} from 'events';
import https from 'https';
import shell from 'electron';
import url from 'url';

/*
Currently, this class doesn't do much. We don't display update notices within
the app because we can't provide a consistent upgrade path for linux users.
However, we still want the app to report to our autoupdate service so we know
how many Linux users exist.
*/
class LinuxUpdaterAdapter extends EventEmitter {
  setFeedURL(feedURL) {
    this.feedURL = feedURL;
    this.downloadURL = null;
  }

  onError = (err) => {
    this.emit('error', err.toString());
  }

  checkForUpdates() {
    if (!this.feedURL) {
      return;
    }

    this.emit('checking-for-update');

    const feedHost = url.parse(this.feedURL).hostname;
    const feedPath = this.feedURL.split(feedHost).pop();

    // Hit the feed URL ourselves and see if an update is available.
    // On linux we can't autoupdate, but we can still show the "update available" bar.
    https.get({ host: feedHost, path: feedPath }, (res) => {
      console.log(`Manual update check returned ${res.statusCode}`);

      if (res.statusCode === 204) {
        this.emit('update-not-available');
        return;
      }

      let data = '';
      res.on('error', this.onError);
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          console.log(JSON.stringify(json, null, 2));
          if (!json.url) {
            this.onError(new Error(`Autoupdater response did not include URL: ${data}`));
            return;
          }
          this.downloadURL = url;
          this.emit('update-downloaded', 'Click to download.', null);
        } catch (err) {
          this.onError(err);
        }
      });
    });
  }

  quitAndInstall() {
    if (this.downloadURL) {
      shell.openExternal(this.downloadURL);
    }
  }
}

export default new LinuxUpdaterAdapter()
