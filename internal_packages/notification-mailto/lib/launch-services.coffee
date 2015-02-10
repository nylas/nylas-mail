exec = require('child_process').exec
fs = require('fs')

bundleIdentifier = 'com.inbox.edgehill'

module.exports =
class LaunchServices

  constructor: ->
    @secure = false

  getPlatform: ->
    process.platform

  available: ->
    @getPlatform() is 'darwin'

  getLaunchServicesPlistPath: (callback) ->
    secure = "#{process.env.HOME}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
    insecure = "#{process.env.HOME}/Library/Preferences/com.apple.LaunchServices.plist"

    fs.exists secure, (exists) =>
      if exists
        callback(secure)
      else
        callback(insecure)

  readDefaults: (callback) ->
    @getLaunchServicesPlistPath (plistPath) =>
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
