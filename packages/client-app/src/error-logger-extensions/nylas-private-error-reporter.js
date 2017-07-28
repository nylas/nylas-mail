/* eslint global-require: 0 */
const getMac = require('getmac').getMac
const crypto = require('crypto')
const Raven = require('raven');
//
// NOTE: This file is manually copied over from the K2 repo into Nylas Mail.
// You must manually update both files. We can't use a sym-link because require
// paths don't work properly.
//

let app;

const sentryDSN = null; // "https://XXX:XXX@sentry.io/XXX";

class ErrorReporter {

  constructor(modes) {
    this.reportError = this.reportError.bind(this)
    this.onDidLogAPIError = this.onDidLogAPIError.bind(this);
    this.inSpecMode = modes.inSpecMode
    this.inDevMode = modes.inDevMode
    this.resourcePath = modes.resourcePath
    this.deviceHash = "Unknown Device Hash"
    this.rateLimitDataByKey = new Map()

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
    if (!this._shouldReportError(extra)) { return }

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

    for (const obj of captureObjects) {
      if (!sentryDSN) {
        return;
      }
      Raven.captureException(err, Object.assign(errData, obj))
    }
  }

  _shouldReportError(extra = {}) {
    const {rateLimit} = extra
    delete extra.rateLimit
    const {key: rateLimitKey, ratePerHour} = rateLimit || {}
    if (!rateLimitKey || !ratePerHour) {
      return true
    }
    if (!this.rateLimitDataByKey.has(rateLimitKey)) {
      this.rateLimitDataByKey.set(rateLimitKey, {
        leftInHour: ratePerHour - 1,
        hourStarted: Date.now(),
      })
      return true
    }

    const {leftInHour, hourStarted} = this.rateLimitDataByKey.get(rateLimitKey)
    const oneHourTimestamp = hourStarted + (60 * 60 * 1000)
    const now = Date.now()
    if (now >= oneHourTimestamp) {
      this.rateLimitDataByKey.set(rateLimitKey, {
        leftInHour: ratePerHour - 1,
        hourStarted: now,
      })
      return true
    }
    if (leftInHour > 0) {
      this.rateLimitDataByKey.set(rateLimitKey, {
        hourStarted,
        leftInHour: leftInHour - 1,
      })
      return true
    }
    return false
  }

  _setupSentry() {
    // Initialize the Sentry connector
    if (!sentryDSN) {
      return;
    }
    Raven.disableConsoleAlerts();
    Raven.config(sentryDSN, {
      name: this.deviceHash,
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

    // https://docs.sentry.io/learn/rollups/#customize-grouping-with-fingerprints
    const fingerprint = extra.fingerprint;
    // The error-handling codepath of Nylas Mail involves several steps which
    // end with reporter extensions being called always with two arguments:
    // the Error object, and `extra`, which is an arbitrary object that
    // contains any extra params. The Sentry API _also_ takes an `extra`
    // param which contains arbitrary extra data. In order to avoid changing
    // the whole error reporting extension API to be less generic, when
    // reporting data to Sentry we pass in some `extra` params that should be
    // sent to Sentry in non-`extra` params, and then delete them from the
    // `extra` object so it's not sending confusing duplicate information.
    // This should not affect other plugins as these deleted params are
    // Sentry-specific.
    if (extra.fingerprint) delete extra.fingerprint;

    if (extra && extra.pluginIds && extra.pluginIds.length > 0) {
      const captureObjects = [];
      for (const pluginId of extra.pluginIds) {
        const obj = {
          extra: extra,
          tags: {
            platform: process.platform,
            version: this.getVersion(),
            pluginId: pluginId,
          },
        };
        if (fingerprint) {
          obj.fingerprint = fingerprint;
        }
        captureObjects.push(obj);
      }
      if (extra.pluginIds) delete extra.pluginIds;
      return captureObjects
    }
    const objs = [{
      extra: extra,
      tags: {
        platform: process.platform,
        version: this.getVersion(),
      },
    }];
    if (fingerprint) objs[0].fingerprint = fingerprint;
    return objs;
  }
}

module.exports = ErrorReporter;
