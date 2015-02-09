exec = require('child_process').exec
fs = require('fs')

bundleIdentifier = 'com.inbox.edgehill'
launchServicesPlistPath = "#{process.env.HOME}/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"

module.exports =
class LaunchServices

  constructor: ->
    @secure = false

  getPlatform: ->
    process.platform

  available: ->
    @getPlatform() is 'darwin'

  isYosemiteOrGreater: (callback) ->
    fs.exists launchServicesPlistPath, (exists) =>
      callback(exists)

  readDefaults: (callback) ->
    return callback(@_defaults) if @_defaults
    @isYosemiteOrGreater (result) =>
      if result
        @_readDefaultsSecure(callback)
      else
        @_readDefaultsPreYosemite(callback)

  _readDefaultsSecure: (callback) ->
    @secure = true
    tmpPath = "#{launchServicesPlistPath}.#{Math.random()}"
    exec "plutil -convert json \"#{launchServicesPlistPath}\" -o \"#{tmpPath}\"", (err, stdout, stderr) =>
      return callback(err) if callback and err
      fs.readFile tmpPath, (err, data) =>
        return callback(err) if callback and err
        try
          data = JSON.parse(data)
          callback(data['LSHandlers'], data)
          fs.unlink(tmpPath)
        catch e
          callback(e) if callback and err

  _readDefaultsPreYosemite: (callback) ->
    @secure = false
    exec "defaults read com.apple.launchservices LSHandlers", (err, stdout, stderr) =>
      return callback(err) if callback and err

      # Convert the defaults from Apple's plist format into
      # JSON. It's nearly the same, just has different delimiters
      plist = stdout.toString()
      regex = /([a-zA-Z]*) = (.*);/
      while (match = regex.exec(plist)) != null
        [text, key, val] = match
        val = "\"#{val}\"" unless val[0] is '"'
        plist = plist.replace(text, "\"#{key}\":#{val},")
      plist = plist.replace(/\(/g, '[')
      plist = plist.replace(/\)/g, ']')
      plist = plist.replace(/[\s]*,[\s]*\n[\s]*}/g, '\n}')

      json = []
      if plist.length > 0
        json = JSON.parse(plist)

      callback(json)

  writeDefaults: (defaults, callback) ->
    @_defaults = defaults
    if @secure
      @_writeDefaultsSecure(defaults, callback)
    else
      @_writeDefaultsPreYosemite(defaults, callback)

  _writeDefaultsSecure: (newDefaults, callback) ->
    @_readDefaultsSecure (currentDefaults, entireFileJSON) =>
        entireFileJSON['LSHandlers'] = newDefaults
        data = JSON.stringify(entireFileJSON)
        tmpPath = "#{launchServicesPlistPath}.json"
        fs.writeFile tmpPath, data, (err) =>
          return callback(err) if callback and err
          exec "plutil -convert binary1 \"#{tmpPath}\" -o \"#{launchServicesPlistPath}\"", =>
            fs.unlink(tmpPath)
            @triggerSystemReload(callback)

  _writeDefaultsPreYosemite: (defaults, callback) ->
    # Convert the defaults JSON back into Apple's json-like
    # format. (I think it predates JSON?)
    json = JSON.stringify(defaults)
    plist = json.replace(/\[/g, '(')
    plist = plist.replace(/\]/g, ')')
    regex = /\"([a-zA-Z^"]*)\":\"([^"]*)\",?/
    while (match = regex.exec(plist)) != null
      [text, key, val] = match
      plist = plist.replace(text, "#{key} = \"#{val}\";")

    # Write the new defaults back to the system
    exec "defaults write ~/Library/Preferences/com.apple.LaunchServices.plist LSHandlers '#{plist}'", (err, stdout, stderr) =>
      return callback(err) if callback and err
      @triggerSystemReload(callback)

  triggerSystemReload: (callback) ->
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
