// This file cannot be Coffeescript because it loads before the Coffeescript
// interpreter. Note that it runs in both browser and renderer processes.

var ErrorReporter, raven, _;
raven = require('raven');
_ = require('underscore');

module.exports = ErrorReporter = (function() {
  function ErrorReporter() {
    var self = this;

    // Initialize the Sentry connector
    this.client = new raven.Client('https://abd4b2a3435847db8fff445e396f2a6d:3df1cca30d7c42419b5a5d9369a794e6@app.getsentry.com/36030');
    this.client.on('error', function(e) {
      console.log(e.reason);
      console.log(e.statusCode);
      return console.log(e.response);
    });

    // Link to the appropriate error handlers for the browser
    // or renderer process
    if (process.type === 'renderer') {
      this.spec = atom.inSpecMode();
      this.dev = atom.inDevMode();

      atom.onDidThrowError(function(_arg) {
        return self.reportError(_arg.originalError, {
          'message': _arg.message
        });
      });

    } else if (process.type === 'browser') {
      var nslog = require('nslog');
      console.log = nslog;

      process.on('uncaughtException', function(error) {
        if (error == null) {
          error = {};
        }
        self.reportError(error);
        if (error.message != null) {
          nslog(error.message);
        }
        if (error.stack != null) {
          return nslog(error.stack);
        }
      });
    }
  }

  ErrorReporter.prototype.getVersion = function() {
    var _ref;
    return (typeof atom !== "undefined" && atom !== null ? atom.getVersion() : void 0) ||
           ((_ref = require('app')) != null ? _ref.getVersion() : void 0);
  };

  ErrorReporter.prototype.reportError = function(err, metadata) {
    if (this.spec) {
      return;
    }
    if (this.dev) {
      return;
    }
    return this.client.captureError(err, {
      extra: metadata,
      tags: {
        'platform': process.platform,
        'version': this.getVersion()
      }
    });
  };

  return ErrorReporter;

})();
