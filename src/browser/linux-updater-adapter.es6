import {EventEmitter} from 'events';
import request from 'request';
import _ from 'underscore';

/*
Currently, this class doesn't do much. We don't display update notices within
the app because we can't provide a consistent upgrade path for linux users.
However, we still want the app to report to our autoupdate service so we know
how many Linux users exist.
*/
class LinuxUpdaterAdapter {

  setFeedURL(feedURL) {
    this.feedURL = feedURL;
  }

  checkForUpdates() {
    if (!this.feedURL) {
      return;
    }
    request(this.feedURL, () => {
    });
  }

  quitAndInstall() {

  }
}

_.extend(LinuxUpdaterAdapter.prototype, EventEmitter.prototype);
module.exports = new LinuxUpdaterAdapter()
