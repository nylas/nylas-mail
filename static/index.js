/* This is to prevent React from displaying an annoying message about
  installing their dev tools. The React dev tools put a variable on the
  global scope. We need to do it here before React loads. */
window.__REACT_DEVTOOLS_GLOBAL_HOOK__ = {}


function registerRuntimeTranspilers(hotreload) {
  // This sets require.extensions['.coffee'].
  require('coffee-script').register();

  // This sets require.extensions['.cjsx']
  if (hotreload) {
    // This is custom built to look at window.devMode and enable hot-reloading
    require('../src/cjsx').register();
  } else {
    require('coffee-react/register');
  }
  // This redefines require.extensions['.js'].
  require('../src/6to5').register();
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

    var registerBeforeModuleCache = loadSettings.devMode || !loadSettings.resourcePath.startsWith(process.resourcesPath + path.sep);
    var hotreload = loadSettings.devMode && !loadSettings.isSpec;

    // Require before the module cache in dev mode
    if (registerBeforeModuleCache) {
      registerRuntimeTranspilers(hotreload);
    }

    ModuleCache = require('../src/module-cache');
    ModuleCache.register(loadSettings);
    ModuleCache.add(loadSettings.resourcePath);

    // Start the crash reporter before anything else.
    require('crash-reporter').start({
      productName: 'Atom',
      companyName: 'GitHub',
      /* By explicitly passing the app version here, we could save the call
      of "require('remote').require('app').getVersion()". */
      extra: {_version: loadSettings.appVersion}
    });

    require('vm-compatibility-layer');

    if (!registerBeforeModuleCache) {
      registerRuntimeTranspilers(hotreload);
    }

    require('../src/coffee-cache').register();

    require(loadSettings.bootstrapScript);

    if (global.atom) {
      global.atom.loadTime = Date.now() - startTime;
      console.log('Window load time: ' + global.atom.getWindowLoadTime() + 'ms');
    } else {
      require('ipc').sendChannel('window-command', 'window:loaded');
    }
  }
  catch (error) {
    var currentWindow = require('remote').getCurrentWindow();
    currentWindow.setSize(800, 600);
    currentWindow.center();
    currentWindow.show();
    currentWindow.openDevTools();
    console.error(error.stack || error);
    console.error(error.message, error);
  }
}
