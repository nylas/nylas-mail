# A single user identity: a key, a way to find that key, one or more email
# addresses, and a keybase profile

{Utils} = require 'nylas-exports'

module.exports =
class Identity
  constructor: ({key, path, addresses, isPriv, keybase_profile}) ->
    @clientId = Utils.generateTempId()
    @key = key ? null # keybase keymanager object
    @path = path ? null # path to the key's file on disk
    @isPriv = isPriv ? false # is this a private key?
    @timeout = null # the time after which this key (if private) needs to be
                    # unlocked again
    @addresses = addresses ? [] # email addresses associated with this identity
    @keybase_profile = keybase_profile ? null # a kb profile object associated with this identity

    if @isPriv
      @setTimeout()

  fingerprint: ->
    if @key?
      return @key.get_pgp_fingerprint().toString('hex')
    return null

  setTimeout: ->
    timeout = 1000 * 60 * 30 # 30 minutes in ms
    @timeout = Date.now() + timeout

  isTimedOut: ->
    return @timeout < Date.now()

  uid: ->
    if key.key?
      uid = key.key.get_pgp_fingerprint().toString('hex')
    else if key.keybase_profile?
      uid = key.keybase_profile.components.username.val
    else if key.addresses.length > 0
      uid = key.addresses.join('')
    else
      uid = @clientId

    return uid
