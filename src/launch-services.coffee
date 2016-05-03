exec = require('child_process').exec
app = require('electron').remote.app
fs = require('fs')
bundleIdentifier = 'com.nylas.nylas-mail'

class LaunchServicesLinux
  isRegisteredForURLScheme: (scheme, callback) ->
    throw new Error "isRegisteredForURLScheme is async, provide a callback" unless callback
    exec "xdg-mime query default x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if callback and err
      callback(stdout.trim() is 'nylas.desktop')

  resetURLScheme: (scheme, callback) ->
    exec "xdg-mime default thunderbird.desktop x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if callback and err
      callback(null, null) if callback

  registerForURLScheme: (scheme, callback) ->
    exec "xdg-mime default nylas.desktop x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if callback and err
      callback(null, null) if callback

class LaunchServicesMac
  constructor: ->
    @secure = false

  getLaunchServicesPlistPath: (callback) ->
    secure = "#{process.env.HOME}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
    insecure = "#{process.env.HOME}/Library/Preferences/com.apple.LaunchServices.plist"

    fs.exists secure, (exists) ->
      if exists
        callback(secure)
      else
        callback(insecure)

  readDefaults: (callback) ->
    @getLaunchServicesPlistPath (plistPath) ->
      tmpPath = "#{plistPath}.#{Math.random()}"
      exec "plutil -convert json \"#{plistPath}\" -o \"#{tmpPath}\"", (err, stdout, stderr) ->
        return callback(err) if callback and err
        fs.readFile tmpPath, (err, data) ->
          return callback(err) if callback and err
          try
            data = JSON.parse(data)
            callback(data['LSHandlers'], data)
            fs.unlink(tmpPath)
          catch e
            callback(e) if callback and err

  writeDefaults: (defaults, callback) ->
    @getLaunchServicesPlistPath (plistPath) ->
      tmpPath = "#{plistPath}.#{Math.random()}"
      exec "plutil -convert json \"#{plistPath}\" -o \"#{tmpPath}\"", (err, stdout, stderr) ->
        return callback(err) if callback and err
        try
          data = fs.readFileSync(tmpPath)
          data = JSON.parse(data)
          data['LSHandlers'] = defaults
          data = JSON.stringify(data)
          fs.writeFileSync(tmpPath, data)
        catch error
          return callback(error) if callback and error

        exec "plutil -convert binary1 \"#{tmpPath}\" -o \"#{plistPath}\"", ->
          fs.unlink(tmpPath)
          exec "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user", (err, stdout, stderr) ->
            callback(err) if callback

  isRegisteredForURLScheme: (scheme, callback) ->
    throw new Error "isRegisteredForURLScheme is async, provide a callback" unless callback
    @readDefaults (defaults) ->
      for def in defaults
        if def.LSHandlerURLScheme is scheme
          return callback(def.LSHandlerRoleAll is bundleIdentifier)
      callback(false)

  resetURLScheme: (scheme, callback) ->
    @readDefaults (defaults) =>
      # Remove anything already registered for the scheme
      for ii in [defaults.length-1..0] by -1
        if defaults[ii].LSHandlerURLScheme is scheme
          defaults.splice(ii, 1)
      @writeDefaults(defaults, callback)

  registerForURLScheme: (scheme, callback) ->
    @readDefaults (defaults) =>
      # Remove anything already registered for the scheme
      for ii in [defaults.length-1..0] by -1
        if defaults[ii].LSHandlerURLScheme is scheme
          defaults.splice(ii, 1)

      # Add our scheme default
      defaults.push
        LSHandlerURLScheme: scheme
        LSHandlerRoleAll: bundleIdentifier

      @writeDefaults(defaults, callback)


class LaunchServicesElectron
  constructor: ->

  isRegisteredForURLScheme: (scheme, callback) ->
    process.nextTick =>
      callback(app.isDefaultProtocolClient(scheme))

  resetURLScheme: (scheme, callback) ->
    process.nextTick =>
      app.removeAsDefaultProtocolClient(scheme)
      callback(null, null) if callback

  registerForURLScheme: (scheme, callback) ->
    process.nextTick =>
      app.setAsDefaultProtocolClient(scheme)
      callback(null, null) if callback

module.exports = LaunchServicesElectron
if process.platform is 'darwin'
  module.exports = LaunchServicesMac
else if process.platform is 'linux'
  module.exports = LaunchServicesLinux

module.exports.LaunchServicesMac = LaunchServicesMac
module.exports.LaunchServicesLinux = LaunchServicesLinux
module.exports.LaunchServicesElectron = LaunchServicesElectron
