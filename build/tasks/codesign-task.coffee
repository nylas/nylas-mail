path = require 'path'
fs = require 'fs-plus'

# Edgehill introduces the KEYCHAIN_ACCESS environment variable. This is
# injected via Jenkins. It is of the form:
#
#     /full/keychain/path/login.keychain:password
#
# The KEYCHAIN_ACCESS variable is saved in a Jenkins Credential and
# injected via the Credentials Binding Plugin.
#
module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'codesign', 'Codesign the app', ->
    done = @async()

    if process.platform is 'darwin' and (process.env.XCODE_KEYCHAIN or process.env.KEYCHAIN_ACCESS)
      unlockKeychain (error) ->
        if error?
          done(error)
        else
          signApp(done)
    else
      signApp(done)

  unlockKeychain = (callback) ->
    cmd = 'security'
    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN, KEYCHAIN_ACCESS} = process.env

    if KEYCHAIN_ACCESS?
      [XCODE_KEYCHAIN, XCODE_KEYCHAIN_PASSWORD] = KEYCHAIN_ACCESS.split(":")

    args = ['unlock-keychain', '-p', XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN]
    spawn {cmd, args}, (error) -> callback(error)

  signApp = (callback) ->
    switch process.platform
      when 'darwin'
        cmd = 'codesign'
        args = ['--deep', '--force', '--verbose', '--sign', 'Developer ID Application: InboxApp, Inc.', grunt.config.get('nylasGruntConfig.shellAppDir')]
        spawn {cmd, args}, (error) -> callback(error)
      when 'win32'
        # TODO: Don't do anything now, because we need a certificate pfx file
        # issued from a certificate authority, and we don't have one.
        return callback()
        spawn {cmd: 'taskkill', args: ['/F', '/IM', 'nylas.exe']}, ->
          cmd = process.env.JANKY_SIGNTOOL ? 'signtool'
          args = ['sign', path.join(grunt.config.get('nylasGruntConfig.shellAppDir'), 'nylas.exe')]

          spawn {cmd, args}, (error) ->
            return callback(error) if error?

            setupExePath = path.resolve(grunt.config.get('nylasGruntConfig.buildDir'), 'installer', 'NylasSetup.exe')
            if fs.isFileSync(setupExePath)
              args = ['sign', setupExePath]
              spawn {cmd, args}, (error) -> callback(error)
            else
              callback()
      else
        callback()
