exec = require('child_process').exec

bundleIdentifier = 'com.inbox.edgehill'

module.exports =
class LaunchServices

  getPlatform: ->
    process.platform

  available: ->
    @getPlatform() is 'darwin'

  readDefaults: (callback) ->
    return callback(@_defaults) if @_defaults
    exec "defaults read com.apple.launchservices LSHandlers", (err, stdout, stderr) ->
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

      json = {}
      if plist.length > 0
        json = JSON.parse(plist)

      callback(json)
  
  writeDefaults: (defaults, callback) ->
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
      @_defaults = defaults
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

