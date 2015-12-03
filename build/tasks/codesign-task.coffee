_ = require 'underscore'
path = require 'path'
fs = require 'fs-plus'

# Codesigning is a Mac-only process that requires a valid Apple
# certificate, the private key, and access to the Mac keychain.
#
# We can only codesign from keys in the keychain. At the end of the day we need
# the certificate and private key to exist in the keychain, and these two
# variables to be set:
#
# XCODE_KEYCHAIN - The path to the keychain we're using
# XCODE_KEYCHAIN_PASSWORD - The keychain password
#
# If these variables are already set we don't have to do anything.
#
# If the keychain and password already exists, we'll know by detecting the
# KEYCHAIN_ACCESS environment variable. It is of the form:
#
#     /full/keychain/path/login.keychain:password
#
# In the case of Travis, we need to setup a temp keychain from encrypted files
# in the repository.  # We'll decrypt and import our certificates, put them in
# a temporary keychain, and use that.
#
# If you want to verify the app was signed you can run the commands:
#
#     spctl -a -t exec -vv /path/to/N1.app
#
# Which should return "satisfies its Designated Requirement"
#
# And:
#
#     codesign --verify --deep --verbose=2 /path/to/N1.app
#
# Which should return "accepted"
module.exports = (grunt) ->
  {spawnP, shouldPublishBuild} = require('./task-helpers')(grunt)
  tmpKeychain = "n1-build.keychain"

  grunt.registerTask 'codesign', 'Codesign the app', ->
    done = @async()
    return unless process.platform is 'darwin'

    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN} = process.env
    if XCODE_KEYCHAIN? and XCODE_KEYCHAIN_PASSWORD?
      unlockKeychain(XCODE_KEYCHAIN, XCODE_KEYCHAIN_PASSWORD)
      .then(signApp)
      .then(verifyApp).then(done).catch(grunt.fail.fatal)
    else if process.env.KEYCHAIN_ACCESS?
      [XCODE_KEYCHAIN, XCODE_KEYCHAIN_PASSWORD] = KEYCHAIN_ACCESS.split(":")
      unlockKeychain(XCODE_KEYCHAIN, XCODE_KEYCHAIN_PASSWORD)
      .then(signApp)
      .then(verifyApp).then(done).catch(grunt.fail.fatal)
    else if process.env.TRAVIS
      if shouldPublishBuild()
        buildTravisKeychain()
        .then(_.partial(signApp, tmpKeychain))
        .then(verifyApp)
        .then(cleanupKeychain)
        .then(done).catch(grunt.fail.fatal)
      else
        return done()
    else
      grunt.fail.fatal("Can't codesign without keychain or certs")

  unlockKeychain = (keychain, keychainPass) ->
    args = ['unlock-keychain', '-p', keychainPass, keychain]
    spawnP("security", args)

  signApp = (keychain) ->
    devId = 'Developer ID Application: InboxApp, Inc.'
    appPath = grunt.config.get('nylasGruntConfig.shellAppDir')
    args = ['--deep', '--force', '--verbose', '--sign', devId]
    args.push("--keychain", keychain) if keychain
    args.push(appPath)
    spawnP("codesign", args)

  buildTravisKeychain = ->
    crypto = require('crypto')
    tmpPass = crypto.randomBytes(32).toString('hex')
    {appleCert, nylasCert, nylasPrivateKey, keyPass} = getCertData()
    codesignBin = path.join("/", "usr","bin", "codesign")

    # Create a custom, temporary keychain
    cleanupKeychain()
    .then -> spawnP("security", ["create-keychain", '-p', tmpPass, tmpKeychain])

    # Make the custom keychain default, so xcodebuild will use it for signing
    .then -> spawnP("security", ["default-keychain", "-s", tmpKeychain])

    # Unlock the keychain
    .then -> unlockKeychain(tmpKeychain, tmpPass)

    # Set keychain timeout to 1 hour for long builds
    .then -> spawnP("security", ["set-keychain-settings", "-t", "3600", "-l", tmpKeychain])

    # Add certificates to keychain and allow codesign to access them
    .then -> spawnP("security", ["import", appleCert, "-k", tmpKeychain, "-T", codesignBin])

    .then -> spawnP("security", ["import", nylasCert, "-k", tmpKeychain, "-T", codesignBin])

    # Load the password for the private key from environment variables
    .then -> spawnP("security", ["import", nylasPrivateKey, "-k", tmpKeychain, "-P", keyPass, "-T", codesignBin])

  verifyApp = ->
    appPath = grunt.config.get('nylasGruntConfig.shellAppDir')
    spawnP("codesign", ["--verify", "--deep", "--verbose=2", appPath])
    .then -> spawnP("spctl", ["-a", "-t", "exec", "-vv", appPath])

  cleanupKeychain = ->
    if fs.existsSync(path.join(process.env.HOME, "Library", "Keychains", tmpKeychain))
      return spawnP("security", ["delete-keychain", tmpKeychain])
    else return Promise.resolve()

  getCertData = ->
    certs = path.resolve(path.join('build', 'resources', 'certs'))
    appleCert = path.join(certs, 'AppleWWDRCA.cer')
    nylasCert = path.join(certs, 'mac-nylas-n1.cer')
    nylasPrivateKey = path.join(certs, 'mac-nylas-n1.p12')

    keyPass = process.env.APPLE_CODESIGN_KEY_PASSWORD

    if not keyPass
      throw new Error("APPLE_CODESIGN_KEY_PASSWORD must be set")
    if not fs.existsSync(appleCert)
      throw new Error("#{appleCert} doesn't exist")
    if not fs.existsSync(nylasCert)
      throw new Error("#{nylasCert} doesn't exist")
    if not fs.existsSync(nylasPrivateKey)
      throw new Error("#{nylasPrivateKey} doesn't exist")

    return {appleCert, nylasCert, nylasPrivateKey, keyPass}
