var app, errorReporter, fs, lstatSyncNoException, optimist, parseCommandLine, path, setupCoffeeScript, setupCrashReporter, start, statSyncNoException, _ref;

global.shellStartTime = Date.now();

errorReporter = new (require('../error-reporter'));

app = require('app');

fs = require('fs');

path = require('path');

optimist = require('optimist');

lstatSyncNoException = fs.lstatSyncNoException, statSyncNoException = fs.statSyncNoException;

fs.statSyncNoException = function(pathToStat) {
  if (!(pathToStat && typeof pathToStat === 'string')) {
    return false;
  }
  return statSyncNoException(pathToStat);
};

fs.lstatSyncNoException = function(pathToStat) {
  if (!(pathToStat && typeof pathToStat === 'string')) {
    return false;
  }
  return lstatSyncNoException(pathToStat);
};

start = function() {
  var SquirrelUpdate, addPathToOpen, addUrlToOpen, args, squirrelCommand;
  if (process.platform === 'win32') {
    SquirrelUpdate = require('./squirrel-update');
    squirrelCommand = process.argv[1];
    if (SquirrelUpdate.handleStartupEvent(app, squirrelCommand)) {
      return;
    }
  }
  args = parseCommandLine();
  addPathToOpen = function(event, pathToOpen) {
    event.preventDefault();
    return args.pathsToOpen.push(pathToOpen);
  };
  args.urlsToOpen = [];
  addUrlToOpen = function(event, urlToOpen) {
    event.preventDefault();
    return args.urlsToOpen.push(urlToOpen);
  };
  app.on('open-file', addPathToOpen);
  app.on('open-url', addUrlToOpen);
  app.on('will-finish-launching', function() {
    return setupCrashReporter();
  });
  return app.on('ready', function() {
    var Application;
    app.removeListener('open-file', addPathToOpen);
    app.removeListener('open-url', addUrlToOpen);
    args.pathsToOpen = args.pathsToOpen.map(function(pathToOpen) {
      var _ref;
      return path.resolve((_ref = args.executedFrom) != null ? _ref : process.cwd(), pathToOpen.toString());
    });
    setupCoffeeScript();
    if (args.devMode) {
      require(path.join(args.resourcePath, 'src', 'coffee-cache')).register();
      Application = require(path.join(args.resourcePath, 'src', 'browser', 'application'));
    } else {
      Application = require('./application');
    }
    Application.open(args);
    if (!args.test) {
      return console.log("App load time: " + (Date.now() - global.shellStartTime) + "ms");
    }
  });
};

global.devResourcePath = (_ref = process.env.EDGEHILL_PATH) != null ? _ref : process.cwd();

if (global.devResourcePath) {
  global.devResourcePath = path.normalize(global.devResourcePath);
}

setupCrashReporter = function() {};

setupCoffeeScript = function() {
  var CoffeeScript;
  CoffeeScript = null;
  return require.extensions['.coffee'] = function(module, filePath) {
    var coffee, js;
    if (CoffeeScript == null) {
      CoffeeScript = require('coffee-script');
    }
    coffee = fs.readFileSync(filePath, 'utf8');
    js = CoffeeScript.compile(coffee, {
      filename: filePath
    });
    return module._compile(js, filePath);
  };
};

parseCommandLine = function() {
  var args, devMode, executedFrom, logFile, newWindow, options, packageDirectoryPath, packageManifest, packageManifestPath, pathsToOpen, pidToKillWhenClosed, resourcePath, safeMode, specDirectory, specFilePattern, test, version;
  version = app.getVersion();
  options = optimist(process.argv.slice(1));
  options.usage("Atom Editor v" + version + "\n\nUsage: atom [options] [path ...]\n\nOne or more paths to files or folders to open may be specified.\n\nFile paths will open in the current window.\n\nFolder paths will open in an existing window if that folder has already been\nopened or a new window if it hasn't.\n\nEnvironment Variables:\nEDGEHILL_PATH  The path from which Atom loads source code in dev mode.\n               Defaults to `cwd`.");
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.');
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.');
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.');
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.');
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.');
  options.alias('r', 'resource-path').string('r').describe('r', 'Set the path to the Atom source directory and enable dev-mode.');
  options.alias('s', 'spec-directory').string('s').describe('s', 'Set the directory from which to run package specs (default: Atom\'s spec directory).');
  options.boolean('safe').describe('safe', 'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.');
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.');
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.');
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.');
  args = options.argv;
  if (args.help) {
    process.stdout.write(options.help());
    process.exit(0);
  }
  if (args.version) {
    process.stdout.write("" + version + "\n");
    process.exit(0);
  }
  executedFrom = args['executed-from'];
  devMode = args['dev'];
  safeMode = args['safe'];
  pathsToOpen = args._;
  if (executedFrom && pathsToOpen.length === 0) {
    pathsToOpen = [executedFrom];
  }
  test = args['test'];
  specDirectory = args['spec-directory'];
  newWindow = args['new-window'];
  if (args['wait']) {
    pidToKillWhenClosed = args['pid'];
  }
  logFile = args['log-file'];
  specFilePattern = args['file-pattern'];
  if (args['resource-path']) {
    devMode = true;
    resourcePath = args['resource-path'];
  } else {
    if (specDirectory != null) {
      packageDirectoryPath = path.resolve(specDirectory, '..');
      packageManifestPath = path.join(packageDirectoryPath, 'package.json');
      if (fs.statSyncNoException(packageManifestPath)) {
        try {
          packageManifest = JSON.parse(fs.readFileSync(packageManifestPath));
          if (packageManifest.name === 'edgehill') {
            resourcePath = packageDirectoryPath;
          }
        } catch (_error) {}
      }
    } else {
      if (test && toString.call(test) === "[object String]") {
        if (test === "core") {
          specDirectory = path.join(global.devResourcePath, "spec-nylas");
        } else {
          specDirectory = path.resolve(path.join(global.devResourcePath, "internal_packages", test));
        }
      }
    }
    if (devMode) {
      if (resourcePath == null) {
        resourcePath = global.devResourcePath;
      }
    }
  }
  if (!fs.statSyncNoException(resourcePath)) {
    resourcePath = path.dirname(path.dirname(__dirname));
  }
  if (args['path-environment']) {
    process.env.PATH = args['path-environment'];
  }
  return {
    resourcePath: resourcePath,
    pathsToOpen: pathsToOpen,
    executedFrom: executedFrom,
    test: test,
    version: version,
    pidToKillWhenClosed: pidToKillWhenClosed,
    devMode: devMode,
    safeMode: safeMode,
    newWindow: newWindow,
    specDirectory: specDirectory,
    logFile: logFile,
    specFilePattern: specFilePattern
  };
};

start();
