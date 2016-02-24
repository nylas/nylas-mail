// This file cannot be Coffeescript because it loads before the
// Coffeescript interpreter. Note that it runs in both browser and
// renderer processes.

var ErrorLogger, _, fs, path, app, os, remote;
os = require('os');
fs = require('fs-plus');
path = require('path');
if (process.type === 'renderer') {
  remote = require('electron').remote;
  app = remote.require('app');
} else {
  app = require('app');
}

// A globally available ErrorLogger that can report errors to various
// sources and enhance error functionality.
//
// This runs in both the backend browser process and each and every
// renderer process.
//
// This is available as `global.errorLogger` in the backend browser
// process.
//
// It is available at `NylasEnv.errorLogger` in each renderer process.
// You should almost always use `NylasEnv.reportError` in the renderer
// processes instead of manually accessing the `errorLogger`
//
// The errorLogger will report errors to a log file as well as to 3rd
// party reporting services if enabled.
module.exports = ErrorLogger = (function() {

  function ErrorLogger(args) {
    this.reportError = this.reportError.bind(this)
    this.inSpecMode = args.inSpecMode
    this.inDevMode = args.inDevMode
    this.resourcePath = args.resourcePath

    this._extendErrorObject()

    this._extendNativeConsole()

    this.extensions = this._setupErrorLoggerExtensions(args)

    if (this.inSpecMode) { return }

    this._cleanOldLogFiles();
    this._setupNewLogFile();
    this._hookProcessOutputsToLogFile();
  }

  /////////////////////////////////////////////////////////////////////
  /////////////////////////// PUBLIC METHODS //////////////////////////
  /////////////////////////////////////////////////////////////////////

  ErrorLogger.prototype.reportError = function(error, extra) {
    var nslog = require('nslog');
    if (!error) { error = {stack: ""} }
    this._appendLog(error.stack)
    if (extra) { this._appendLog(extra) }
    this._notifyExtensions("reportError", error, extra)
    if (process.type === 'browser') { nslog(error.stack) }
  }

  ErrorLogger.prototype.openLogs = function() {
    var shell = require('shell');
    shell.openItem(this._logPath());
  };

  ErrorLogger.prototype.apiDebug = function(error) {
    this._appendLog(error, error.statusCode, error.message);
    this._notifyExtensions("onDidLogAPIError", error);
  }


  /////////////////////////////////////////////////////////////////////
  ////////////////////////// PRIVATE METHODS //////////////////////////
  /////////////////////////////////////////////////////////////////////

  ErrorLogger.prototype._extendNativeConsole = function(args) {
    console.debug = this._consoleDebug.bind(this)

    if (process.type === 'browser' && process.platform === 'darwin') {
      var nslog = require('nslog');
      console.log = nslog;
      console.error = nslog;
    }
  }

  // globally define Error.toJSON. This allows us to pass errors via IPC
  // and through the Action Bridge. Note:they are not re-inflated into
  // Error objects automatically.
  ErrorLogger.prototype._extendErrorObject = function(args) {
    Object.defineProperty(Error.prototype, 'toJSON', {
      value: function () {
        var alt = {};

        Object.getOwnPropertyNames(this).forEach(function (key) {
          alt[key] = this[key];
        }, this);

        return alt;
      },
      configurable: true
    });
  }

  ErrorLogger.prototype._setupErrorLoggerExtensions = function(args) {
    var extension, extensionConstructor, extensionPath, extensions, extensionsPath, i, len, ref;
    if (args == null) {
      args = {};
    }
    extensions = [];
    extensionsPath = path.join(args.resourcePath, 'src', 'error-logger-extensions');
    ref = fs.listSync(extensionsPath);
    for (i = 0, len = ref.length; i < len; i++) {
      extensionPath = ref[i];
      if (path.basename(extensionPath)[0] === '.') {
        continue;
      }
      extensionConstructor = require(extensionPath);
      if (!(typeof extensionConstructor === "function")) {
        throw new Error("Logger Extensions must return an extension constructor");
      }
      extension = new extensionConstructor({
        inSpecMode: args.inSpecMode,
        inDevMode: args.inDevMode,
        resourcePath: args.resourcePath
      });
      extensions.push(extension);
    }
    return extensions;
  };

  ErrorLogger.prototype._logPath = function() {
    var tmpPath = app.getPath('temp');

    var logpid = process.pid;
    if (process.type === 'renderer') {
      logpid = remote.process.pid + "." +  process.pid;
    }
    return path.join(tmpPath, 'Nylas-N1-' + logpid + '.log');
  }

  // If we're the browser process, remove log files that are more than
  // two days old. These log files get pretty big because we're logging
  // so verbosely.
  ErrorLogger.prototype._cleanOldLogFiles = function() {
    if (process.type === 'browser') {
      var tmpPath = app.getPath('temp');
      fs.readdir(tmpPath, function(err, files) {
        if (err) {
          console.error(err);
          return;
        }

        var logFilter = new RegExp("Nylas-N1-[.0-9]*.log$");
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

  ErrorLogger.prototype._setupNewLogFile = function() {
    // Open a file write stream to log output from this process
    console.log("Streaming log data to "+this._logPath());

    this.loghost = os.hostname();
    this.logstream = fs.createWriteStream(this._logPath(), {
      flags: 'a',
      encoding: 'utf8',
      fd: null,
      mode: 0666
    });
  }

  ErrorLogger.prototype._hookProcessOutputsToLogFile = function() {
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
      self._appendLog.apply(self, [string]);
    });
    hook_process_output('stderr', function(string, encoding, fd) {
      self._appendLog.apply(self, [string]);
    });
  }

  ErrorLogger.prototype._notifyExtensions = function() {
    var command, args;
    command = arguments[0]
    args = 2 <= arguments.length ? Array.prototype.slice.call(arguments, 1) : [];
    for (var i=0; i < this.extensions.length; i++) {
      extension = this.extensions[i]
      extension[command].apply(this, args);
    }
  }

  // Create a new console.debug option, which takes `true` (print)
  // or `false`, don't print in console as the first parameter.
  // This makes it easy for developers to turn on and off
  // "verbose console" mode.
  ErrorLogger.prototype._consoleDebug = function() {
    var args = [];
    var showIt = arguments[0];
    for (var ii = 1; ii < arguments.length; ii++) {
      args.push(arguments[ii]);
    }
    if ((this.inDevMode === true) && (showIt === true)) {
      console.log.apply(console, args);
    }
    this._appendLog.apply(this, [args]);
  }

  ErrorLogger.prototype._appendLog = function(obj) {
    if (this.inSpecMode) { return };

    try {
      var message = JSON.stringify({
        host: this.loghost,
        timestamp: (new Date()).toISOString(),
        payload: obj
      })+"\n";

      this.logstream.write(message, 'utf8', function (err) {
        if (err) {
          console.error("ErrorLogger: Unable to write to the log stream!" + err.toString());
        }
      });
    } catch (err) {
      console.error("ErrorLogger: Unable to write to the log stream." + err.toString());
    }
  };

  return ErrorLogger;

})();
