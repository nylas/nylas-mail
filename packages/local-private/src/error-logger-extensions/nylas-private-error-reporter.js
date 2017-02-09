/* eslint global-require: 0 */
const getMac = require('getmac').getMac
const crypto = require('crypto')
const Raven = require('raven');
//
// NOTE: This file is manually copied over from the edgehill repo into N1. You
// must manually update both files. We can't use a sym-link because require
// paths don't work properly.
//

let app;

class ErrorReporter {

  constructor(modes) {
    this.reportError = this.reportError.bind(this)
    this.onDidLogAPIError = this.onDidLogAPIError.bind(this);
    this.inSpecMode = modes.inSpecMode
    this.inDevMode = modes.inDevMode
    this.resourcePath = modes.resourcePath
    this.deviceHash = "Unknown Device Hash"

    if (!this.inSpecMode) {
      try {
        getMac((err, macAddress) => {
          if (!err && macAddress) {
            this.deviceHash = crypto.createHash('md5').update(macAddress).digest('hex')
          }
          this._setupSentry();
        })
      } catch (err) {
        console.error(err);
        this._setupSentry();
      }
    }
  }

  onDidLogAPIError(error, statusCode, message) { // eslint-disable-line

  }

  getVersion() {
    if (process.type === 'renderer') {
      return NylasEnv.getVersion();
    }
    return require('electron').app.getVersion()
  }

  reportError(err, extra) {
    if (this.inSpecMode || this.inDevMode) { return }

    // It's possible for there to be more than 1 sentry capture object.
    // If an error comes from multiple plugins, we report a unique event
    // for each plugin since we want to group by individual pluginId
    const captureObjects = this._prepareSentryCaptureObjects(err, extra)

    if (process.type === 'renderer') {
      app = require('electron').remote.getGlobal('application')
    } else {
      app = global.application
    }

    const errData = {}
    if (typeof app !== 'undefined' && app && app.databaseReader) {
      const fullIdent = app.databaseReader.getJSONBlob("NylasID")
      // We may not have an identity available yet
      if (fullIdent) {
        errData.user = {
          id: fullIdent.id,
          email: fullIdent.email,
          name: `${fullIdent.firstname} ${fullIdent.lastname}`,
        }
      }
    }

    for (let i = 0; i < captureObjects.length; i++) {
      Raven.captureException(err, Object.assign(errData, captureObjects[i]))
    }
  }

  _setupSentry() {
    // Initialize the Sentry connector
    const sentryDSN = "https://0796ad36648a40a094128d6e0287eda4:0c329e562cc74e06a48488772dd0f578@sentry.io/134984"

    Raven.disableConsoleAlerts();
    Raven.config(sentryDSN, {
      name: this.deviceHash,
      autoBreadcrumbs: true,
      release: this.getVersion(),
    }).install();

    Raven.on('error', (e) => {
      console.log(e.reason);
      console.log(e.statusCode);
      return console.log(e.response);
    });
  }

  _prepareSentryCaptureObjects(error, extra) {
    // Never send user auth tokens
    if (error.requestOptions && error.requestOptions.auth) {
      delete error.requestOptions.auth;
    }

    // Never send message bodies
    if (error.requestOptions && error.requestOptions.body && error.requestOptions.body.body) {
      delete error.requestOptions.body.body;
    }

    if (extra && extra.pluginIds && extra.pluginIds.length > 0) {
      const captureObjects = [];
      for (let i = 0; i < extra.pluginIds.length; i++) {
        captureObjects.push({
          extra: extra,
          tags: {
            platform: process.platform,
            version: this.getVersion(),
            pluginId: extra.pluginIds[i],
          },
        });
      }
      return captureObjects
    }
    return [{
      extra: extra,
      tags: {
        platform: process.platform,
        version: this.getVersion(),
      },
    }]
  }
}

module.exports = ErrorReporter;
