/* eslint global-require: 0 */
const { getMac } = require('getmac');
const crypto = require('crypto');
const Raven = require('raven');

module.exports = class RavenErrorReporter {
  constructor({ inSpecMode, inDevMode, resourcePath }) {
    this.inSpecMode = inSpecMode;
    this.inDevMode = inDevMode;
    this.resourcePath = resourcePath;
    this.deviceHash = 'Unknown Device Hash';

    if (!this.inSpecMode) {
      try {
        getMac((err, macAddress) => {
          if (!err && macAddress) {
            this.deviceHash = crypto
              .createHash('md5')
              .update(macAddress)
              .digest('hex');
          }
          this._setupSentry();
        });
      } catch (err) {
        console.error(err);
        this._setupSentry();
      }
    }
  }

  getVersion() {
    return process.type === 'renderer' ? AppEnv.getVersion() : require('electron').app.getVersion();
  }

  reportError(err, extra) {
    if (this.inSpecMode || this.inDevMode) {
      return;
    }

    Raven.captureException(err, {
      extra: extra,
      tags: {
        platform: process.platform,
        version: this.getVersion(),
      },
    });
  }

  _setupSentry() {
    Raven.disableConsoleAlerts();
    Raven.config(
      'https://18d04acdd03b4389a36ef7d1d39f8025:5cb2e99bd3634856bfb3711461201439@sentry.io/196829',
      {
        name: this.deviceHash,
        release: this.getVersion(),
      }
    ).install();

    Raven.on('error', e => {
      console.log(`Raven: ${e.statusCode} - ${e.reason}`);
    });
  }
};
