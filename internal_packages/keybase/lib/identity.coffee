# A single user identity: a key, a way to find that key, one or more email
# addresses, and a keybase profile

{Utils} = require 'nylas-exports'
path = require 'path'

module.exports =
class Identity
  constructor: ({key, addresses, isPriv, keybase_profile}) ->
    @clientId = Utils.generateTempId()
    @key = key ? null # keybase keymanager object
    @isPriv = isPriv ? false # is this a private key?
    @timeout = null # the time after which this key (if private) needs to be unlocked again
    @addresses = addresses ? [] # email addresses associated with this identity
    @keybase_profile = keybase_profile ? null # a kb profile object associated with this identity

    Object.defineProperty(@, 'keyPath', {
      get: ->
        if @addresses.length > 0
          keyDir = path.join(NylasEnv.getConfigDirPath(), 'keys')
          thisDir = if @isPriv then path.join(keyDir, 'private') else path.join(keyDir, 'public')
          keyPath = path.join(thisDir, @addresses.join(" "))
        else
          keyPath = null
        return keyPath
    })

    if @isPriv
      @setTimeout()

  fingerprint: ->
    if @key?
      return @key.get_pgp_fingerprint().toString('hex')
    return null

  setTimeout: ->
    delay = 1000 * 60 * 30 # 30 minutes in ms
    @timeout = Date.now() + delay

  isTimedOut: ->
    return @timeout < Date.now()

  uid: ->
    if @key?
      uid = @key.get_pgp_fingerprint().toString('hex')
    else if @keybase_profile?
      uid = @keybase_profile.components.username.val
    else if @addresses.length > 0
      uid = @addresses.join('')
    else
      uid = @clientId

    return uid
