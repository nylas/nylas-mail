CoffeeScript = require('coffee-react');

// TODO: Remove react-hot-api (which is deprecated) in favor of react-proxy
//
// Note: This uses https://github.com/gaearon/react-hot-api and code from
// https://github.com/BenoitZugmeyer/chwitt-react/blob/2d62184986c7c183955dcb607dba5ceda70a2221/bootstrap-jsx.js

var hotCompile = (function () {
  var fs = require('fs');
  var React = require('react');
  var ReactMount = require('react/lib/ReactMount');
  var reactHotReload;
  try {
      reactHotReload = require('react-hot-api')(function () { return ReactMount._instancesByReactRootID; });
  }
  catch (e) {
      console.log('Not using react hot reload');
  }

  var currentlyCompiling;
  var watchedModules = new WeakSet();
  var requiredBy = new Map();

  function compile(module, filename) {
    return module._compile(CoffeeScript._compileFile(filename, false), filename);
  }

  function monitorHotReload(module) {
    if (watchedModules.has(module)) return;

    watchedModules.add(module);

    var timeout;
    setTimeout(function(){
      var pathwatcher = require('pathwatcher');
      pathwatcher.watch(module.filename, /*{persistent: true},*/ function () {
        clearTimeout(timeout);
        timeout = setTimeout(function () {
          hotCompile(module, module.filename, true);
          console.log('hot reloaded '+module.filename);
        }, 100);
      });
    },100);
  }

  function isReactComponent(module) {
    return reactHotReload && (module.exports.prototype instanceof React.Component);
  }

  function recompileRequirements(module, collection) {
    if (requiredBy.has(module)) {
      var requirements = requiredBy.get(module);
      var m;
      for (m of requirements) {
        if (!collection.has(m)) {
          collection.add(m);
          hotCompile(m, m.filename);
        }
      }

      for (m of requirements) {
        recompileRequirements(m, collection || new WeakSet());
      }
    }
  }

  function monitorRequire(module) {
    if (Object.getOwnPropertyDescriptor(require.cache, module.filename).value) {
      Object.defineProperty(require.cache, module.filename, {
        get: function () {
          onRequired(module);
          return module;
        }
      });
    }
  }

  function onRequired(module) {
    if (currentlyCompiling) {
      if (!requiredBy.has(module)) requiredBy.set(module, new Set());
      requiredBy.get(module).add(currentlyCompiling);
    }
  }

  function removeModuleFromDependencies(module) {
    for (var mod of requiredBy.values()) {
      mod.delete(module);
    }
  }

  function hotCompile(module, filename, withRequirements) {

    monitorRequire(module);
    onRequired(module);

    removeModuleFromDependencies(module);

    var previouslyCompiling = currentlyCompiling;
    currentlyCompiling = module;

    var wasReactComponent = isReactComponent(module);

    var result;
    var failed = false;

    try {
      result = compile(module, filename);
    }
    catch (e) {
      console.log('Error while compiling ' + filename);
      console.log(e.stack);
      failed = true;
    }

    currentlyCompiling = previouslyCompiling;

    monitorHotReload(module);

    if (!failed) {

      if (isReactComponent(module)) {
        reactHotReload(module.exports, module.filename);
      }

      if ((!wasReactComponent || !isReactComponent(module)) && withRequirements) {
        recompileRequirements(module, new Set([module]));
      }
    }

    return result;
  }

  return hotCompile;
}());

function registerHotCompile() {
  require.extensions['.cjsx'] = hotCompile;

  if (process.mainModule === module) {
    var path = require('path');
    require(path.resolve(process.argv[2]));
  }
}

module.exports = {
  register: registerHotCompile
};
