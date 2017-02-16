import NylasStore from 'nylas-store';
import {remote} from 'electron';

import {LegacyEdgehillAPI} from 'nylas-exports';

const autoUpdater = remote.getGlobal('application').autoUpdateManager;
const preferredChannel = autoUpdater.preferredChannel;

class UpdateChannelStore extends NylasStore {
  constructor() {
    super();
    this._current = {name: 'Loading...'};
    this._available = [{name: 'Loading...'}];

    if (NylasEnv.isMainWindow()) {
      this.refreshChannel();
    }
  }

  current() {
    return this._current;
  }

  currentIsUnstable() {
    return this._current && this._current.name.toLowerCase() === 'beta';
  }

  available() {
    return this._available;
  }

  refreshChannel() {
    LegacyEdgehillAPI.makeRequest({
      method: 'GET',
      path: `/update-channel`,
      qs: Object.assign({preferredChannel: preferredChannel}, autoUpdater.parameters()),
      json: true,
    }).run()
    .then(({current, available} = {}) => {
      this._current = current || {name: "Edgehill API Not Available"};
      this._available = available || [];
      this.trigger();
    });
    return null;
  }

  setChannel(channelName) {
    LegacyEdgehillAPI.makeRequest({
      method: 'POST',
      path: `/update-channel`,
      qs: Object.assign({
        channel: channelName,
        preferredChannel: preferredChannel,
      }, autoUpdater.parameters()),
      json: true,
    }).run()
    .then(({current, available} = {}) => {
      this._current = current || {name: "Edgehill API Not Available"};
      this._available = available || [];
      this.trigger();
    }).catch((err) => {
      NylasEnv.showErrorDialog(err.toString())
      this.trigger();
    });
    return null;
  }
}

export default new UpdateChannelStore();
