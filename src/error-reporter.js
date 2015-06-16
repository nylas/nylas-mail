// This file cannot be Coffeescript because it loads before the Coffeescript
// interpreter. Note that it runs in both browser and renderer processes.

var ErrorReporter, raven, _, fs, path, app, os, remote;
raven = require('raven');
os = require('os');
_ = require('underscore');
fs = require('fs-plus');
path = require('path');
if (process.type === 'renderer') {
  remote = require('remote');
  app = remote.require('app');
} else {
  app = require('app');
}

var tmpPath = app.getPath('temp');

var logpid = process.pid;
if (process.type === 'renderer') {
  logpid = remote.process.pid + "." +  process.pid;
}
var logpath = path.join(tmpPath, 'edgehill-' + logpid + '.log');


module.exports = ErrorReporter = (function() {

  function ErrorReporter(modes) {
    var self = this;

    this.inSpecMode = modes.inSpecMode
    this.inDevMode = modes.inDevMode

    if (!this.inSpecMode) {
      this._setupSentry();
      this._cleanOldLogFiles();
      this._setupNewLogFile();
      this._hookProcessOutputs();
      this._catchUncaughtErrors();
    }

    console.debug = _.bind(this.consoleDebug, this);
  }

  ErrorReporter.prototype._setupSentry = function() {
    // Initialize the Sentry connector
    this.client = new raven.Client('https://7a32cb0189ff4595a55c98ffb7939c46:f791c3c402b343068bed056b8b504dd5@sentry.nylas.com/4');
    this.client.on('error', function(e) {
      console.log(e.reason);
      console.log(e.statusCode);
      return console.log(e.response);
    });
  }

  // If we're the browser process, remove log files that are more than
  // two days old. These log files get pretty big because we're logging
  // so verbosely.
  ErrorReporter.prototype._cleanOldLogFiles = function() {
    if (process.type === 'browser') {
      fs.readdir(tmpPath, function(err, files) {
        if (err) {
          console.error(err);
          return;
        }

        var logFilter = new RegExp("edgehill-[.0-9]*.log$");
        files.forEach(function(file) {
          if (logFilter.test(file) === true) {
            var filepath = path.join(tmpPath, file);
            fs.stat(filepath, function(err, stats) {
              var lastModified = new Date(stats['mtime']);
              var fileAge = Date.now() - lastModified.getTime();
              if (fileAge > (1000 * 60 * 60 * 24 * 2)) { // two days
                fs.unlink(filepath);
              }
            });
          }
        });
      });
    }
  }

  ErrorReporter.prototype._setupNewLogFile = function() {
    this.shipLogsQueued = false;
    this.shipLogsTime = 0;

    // Open a file write stream to log output from this process
    console.log("Streaming log data to "+logpath);

    this.loghost = os.hostname();
    this.logstream = fs.createWriteStream(logpath, {
      flags: 'a',
      encoding: 'utf8',
      fd: null,
      mode: 0666
    });
  }

  ErrorReporter.prototype._hookProcessOutputs = function() {
    var self = this;
    // Override stdout and stderr to pipe their output to the file
    // in addition to calling through to the existing implementation
    function hook_process_output(channel, callback) {
      var old_write = process[channel].write;
      process[channel].write = (function(write) {
          return function(string, encoding, fd) {
              write.apply(process[channel], arguments)
              callback(string, encoding, fd)
          }
      })(process[channel].write)

      // Return a function that can be used to undo this change
      return function() {
        process[channel].write = old_write
      };
    }

    hook_process_output('stdout', function(string, encoding, fd) {
      self.appendLog.apply(self, [string]);
    });
    hook_process_output('stderr', function(string, encoding, fd) {
      self.appendLog.apply(self, [string]);
    });
  }

  ErrorReporter.prototype._catchUncaughtErrors = function() {
    var self = this;
    // Link to the appropriate error handlers for the browser
    // or renderer process
    if (process.type === 'renderer') {
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

  // Create a new console.debug option, which takes `true` (print)
  // or `false`, don't print in console as the first parameter.
  // This makes it easy for developers to turn on and off
  // "verbose console" mode.
  ErrorReporter.prototype.consoleDebug = function() {
    var args = [];
    var showIt = arguments[0];
    for (var ii = 1; ii < arguments.length; ii++) {
      args.push(arguments[ii]);
    }
    if ((this.dev === true) && (showIt === true)) {
      console.log.apply(this, args);
    }
    this.appendLog.apply(this, [args]);
  }

  ErrorReporter.prototype.appendLog = function(obj) {
    if (this.inSpecMode) { return };

    try {
      var message = JSON.stringify({
        host: this.loghost,
        timestamp: (new Date()).toISOString(),
        payload: obj
      })+"\n";

      this.logstream.write(message, 'utf8', function (err) {
        if (err) {
          console.error("ErrorReporter: Unable to write to the log stream!" + err.toString());
        }
      });
    } catch (err) {
      console.error("ErrorReporter: Unable to write to the log stream." + err.toString());
    }
  };

  ErrorReporter.prototype.openLogs = function() {
    var shell = require('shell');
    shell.openItem(logpath);
  };

  ErrorReporter.prototype.shipLogs = function(reason) {
    if (this.inSpecMode) { return };

    if (!this.shipLogsQueued) {
      var timeSinceLogShip = Date.now() - this.shipLogsTime;
      if (timeSinceLogShip > 20000) {
        this.runShipLogsTask(reason);
      } else {
        this.shipLogsQueued = true;
        var self = this;
        setTimeout(function() {
          self.runShipLogsTask(reason);
          self.shipLogsQueued = false;
        }, 20000 - timeSinceLogShip);
      }
    }
  };

  ErrorReporter.prototype.runShipLogsTask = function(reason) {
    if (this.inSpecMode) { return };

    var self = this;

    this.shipLogsTime = Date.now();

    if (!reason) {
      reason = "";
    }
    var logPattern = null;
    if (process.type === 'renderer') {
      logPattern = "edgehill-"+remote.process.pid+"[.0-9]*.log$";
    } else {
      logPattern = "edgehill-"+process.pid+"[.0-9]*.log$";
    }

    console.log("ErrorReporter: Shipping Logs. " + reason);

    Task = require('./task');
    ship = Task.once(fs.absolute('./tasks/ship-logs-task'), tmpPath, logPattern, function() {
      self.appendLog("ErrorReporter: Shipped Logs.");
    });
  };


  ErrorReporter.prototype.getVersion = function() {
    var _ref;
    return (typeof atom !== "undefined" && atom !== null ? atom.getVersion() : void 0) ||
           ((_ref = require('app')) != null ? _ref.getVersion() : void 0);
  };

  ErrorReporter.prototype.reportError = function(err, metadata) {
    if (this.inSpecMode || this.inDevMode) { return };

    this.client.captureError(err, {
      extra: metadata,
      tags: {
        'platform': process.platform,
        'version': this.getVersion()
      }
    });

    this.appendLog(err, metadata);
    this.shipLogs('Exception occurred');
  };

  return ErrorReporter;

})();
