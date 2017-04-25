window.eval = global.eval = function() {
  throw new Error("Sorry, N1 does not support window.eval() for security reasons.");
}

var util = require('util')
var path = require('path');
var electron = require('electron');
var remote = electron.remote;
var ipcRenderer = electron.ipcRenderer;

console.inspect = function consoleInspect(val) {
  console.log(util.inspect(val, true, depth=7, colorize=true));
}

function setLoadTime (loadTime) {
  if (global.NylasEnv) {
    global.NylasEnv.loadTime = loadTime;
    if (NylasEnv.inSpecMode()) return;
    console.log('Window load time: ' + global.NylasEnv.getWindowLoadTime() + 'ms')
  }
}

function handleSetupError (error) {
  var errorJSON = "{}";
  try {
    errorJSON = JSON.stringify(error);
  } catch (err) {
    var recoveredError = new Error();
    recoveredError.stack = error.stack;
    recoveredError.message = `Recovered Error: ${error.message}`;
    errorJSON = JSON.stringify(recoveredError)
  }
  console.error(error.stack || error)
  ipcRenderer.sendSync("report-error", {errorJSON: errorJSON})
  var message = `We encountered an unexpected problem starting up Nylas Mail. Please try again.`
  ipcRenderer.send("quit-with-error-message", message)
}

function copyEnvFromMainProcess() {
  var _ = require('underscore');
  var remote = require('electron').remote;
  var newEnv = _.extend({}, process.env, remote.process.env);
  process.env = newEnv;
}

function setupWindow (loadSettings) {
  if (process.platform === 'linux') {
    // This will properly inherit process.env from the main process, which it
    // doesn't do by default on Linux. See:
    // https://github.com/atom/electron/issues/3306
    copyEnvFromMainProcess();
  }

  var CompileCache = require('../src/compile-cache')
  CompileCache.setHomeDirectory(loadSettings.configDirPath)

  var ModuleCache = require('../src/module-cache')
  ModuleCache.register(loadSettings)
  ModuleCache.add(loadSettings.resourcePath)

  // Start the crash reporter before anything else.
  // require('crash-reporter').start({
  //   productName: 'N1',
  //   companyName: 'Nylas',
  //   // By explicitly passing the app version here, we could save the call
  //   // of "require('electron').remote.app.getVersion()".
  //   extra: {_version: loadSettings.appVersion}
  // })

  setupVmCompatibility()

  require(loadSettings.bootstrapScript)
}

function setupVmCompatibility () {
  var vm = require('vm')
  if (!vm.Script.createContext) {
    vm.Script.createContext = vm.createContext
  }
}


window.onload = function() {
  try {
    var startTime = Date.now();

    var fs = require('fs');
    var path = require('path');

    // Skip "?loadSettings=".
    var rawLoadSettings = decodeURIComponent(location.search.substr(14));
    var loadSettings;
    try {
      loadSettings = JSON.parse(rawLoadSettings);
    } catch (error) {
      console.error("Failed to parse load settings: " + rawLoadSettings);
      throw error;
    }

    // Normalize to make sure drive letter case is consistent on Windows
    process.resourcesPath = path.normalize(process.resourcesPath);

    setupWindow(loadSettings)
    setLoadTime(Date.now() - startTime)
  }
  catch (error) {
    handleSetupError(error)
  }
}
