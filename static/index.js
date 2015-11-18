// This is to prevent React from displaying an annoying message about
// installing their dev tools. The React dev tools put a variable on the
// global scope. We need to do it here before React loads.
window.__REACT_DEVTOOLS_GLOBAL_HOOK__ = {}

var path = require('path');

function setLoadTime (loadTime) {
  if (global.NylasEnv) {
    global.NylasEnv.loadTime = loadTime
    console.log('Window load time: ' + global.NylasEnv.getWindowLoadTime() + 'ms')
  }
}

function handleSetupError (error) {
  var currentWindow = require('remote').getCurrentWindow()
  currentWindow.setSize(800, 600)
  currentWindow.center()
  currentWindow.show()
  currentWindow.openDevTools()
  console.error(error.stack || error)
}

function setupWindow (loadSettings) {
  var hotreload = loadSettings.devMode && !loadSettings.isSpec;
  var CompileCache = require('../src/compile-cache')
  CompileCache.setHotReload(hotreload)
  CompileCache.setHomeDirectory(process.env.NYLAS_HOME)

  var ModuleCache = require('../src/module-cache')
  ModuleCache.register(loadSettings)
  ModuleCache.add(loadSettings.resourcePath)

  // Start the crash reporter before anything else.
  require('crash-reporter').start({
    productName: 'N1',
    companyName: 'Nylas',
    // By explicitly passing the app version here, we could save the call
    // of "require('remote').require('app').getVersion()".
    extra: {_version: loadSettings.appVersion}
  })

  setupVmCompatibility()
  setupCsonCache(CompileCache.getCacheDirectory())

  require(loadSettings.bootstrapScript)
  require('ipc').sendChannel('window-command', 'window:loaded')
}

function setupCsonCache (cacheDir) {
  require('season').setCacheDir(path.join(cacheDir, 'cson'))
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

    if (loadSettings.loadingMessage) {
      document.getElementById("application-loading-text-supplement").innerHTML = loadSettings.loadingMessage
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
