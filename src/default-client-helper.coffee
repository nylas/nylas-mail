exec = require('child_process').exec
fs = require('fs')
{remote, shell} = require('electron')

bundleIdentifier = 'com.nylas.nylas-mail'

class Windows
  available: ->
    true

  isRegisteredForURLScheme: (scheme, callback) ->
    throw new Error "isRegisteredForURLScheme is async, provide a callback" unless callback
    output = ""
    exec "reg.exe query HKCU\\SOFTWARE\\Microsoft\\Windows\\Roaming\\OpenWith\\UrlAssociations\\#{scheme}\\UserChoice", (err, stdout, stderr) ->
      output += stdout.toString()
      exec "reg.exe query HKCU\\SOFTWARE\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\#{scheme}\\UserChoice", (err, stdout, stderr) ->
        output += stdout.toString()
        return callback(err) if callback and err
        callback(stdout.includes('Nylas'))

  resetURLScheme: (scheme, callback) ->
    remote.dialog.showMessageBox null, {
      type: 'info',
      buttons: ['Learn More'],
      message: "Visit Windows Settings to change your default mail client",
      detail: "You'll find Nylas Mail, along with other options, listed in Default Apps > Mail.",
    }, ->
      shell.openExternal('https://support.nylas.com/hc/en-us/articles/229277648')

  registerForURLScheme: (scheme, callback) ->
    # Ensure that our registry entires are present
    WindowsUpdater = remote.require('./windows-updater')
    WindowsUpdater.createRegistryEntries({
      allowEscalation: true,
      registerDefaultIfPossible: true,
    }, (err, didMakeDefault) =>
      if err
        remote.dialog.showMessageBox(null, {
          type: 'error',
          buttons: ['OK'],
          message: 'Sorry, an error occurred.',
          detail: err.message,
        })

      if not didMakeDefault
        remote.dialog.showMessageBox null, {
          type: 'info',
          buttons: ['Learn More'],
          defaultId: 1,
          message: "Visit Windows Settings to finish making Nylas Mail your mail client",
          detail: "Click 'Learn More' to view instructions in our knowledge base.",
        }, ->
          shell.openExternal('https://support.nylas.com/hc/en-us/articles/229277648')

      callback(null, null) if callback
    )

class Linux
  available: ->
    true

  isRegisteredForURLScheme: (scheme, callback) ->
    throw new Error "isRegisteredForURLScheme is async, provide a callback" unless callback
    exec "xdg-mime query default x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if err
      callback(stdout.trim() is 'nylas.desktop')

  resetURLScheme: (scheme, callback) ->
    exec "xdg-mime default thunderbird.desktop x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if callback and err
      callback(null, null) if callback

  registerForURLScheme: (scheme, callback) ->
    exec "xdg-mime default nylas.desktop x-scheme-handler/#{scheme}", (err, stdout, stderr) ->
      return callback(err) if callback and err
      callback(null, null) if callback

class Mac
  constructor: ->
    @secure = false

  available: ->
    true

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


if process.platform is 'darwin'
  module.exports = Mac
else if process.platform is 'linux'
  module.exports = Linux
else if process.platform is 'win32'
  module.exports = Windows
else
  module.exports = {}

module.exports.Mac = Mac
module.exports.Linux = Linux
module.exports.Windows = Windows
