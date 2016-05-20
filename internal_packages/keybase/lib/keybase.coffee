_ = require 'underscore'
request = require 'request'

class KeybaseAPI
  constructor: ->
    @baseUrl = "https://keybase.io"

  getUser: (key, keyType, callback) =>
    if not keyType in ['usernames', 'domain', 'twitter', 'github', 'reddit',
                       'hackernews', 'coinbase', 'key_fingerprint']
      console.error 'keyType must be a supported Keybase query type.'

    this._keybaseRequest("/_/api/1.0/user/lookup.json?#{keyType}=#{key}", (err, resp, obj) =>
      return callback(err, null) if err
      return callback(new Error("Empty response!"), null) if not obj? or not obj.them?
      if obj.status?
        return callback(new Error(obj.status.desc), null) if obj.status.name != "OK"

      callback(null, _.map(obj.them, @_regularToAutocomplete))
    )

  getKey: (username, callback) =>
    request({url: @baseUrl + "/#{username}/key.asc", headers: {'User-Agent': 'request'}}, (err, resp, obj) =>
      return callback(err, null) if err
      return callback(new Error("No key found for #{username}"), null) if not obj?
      return callback(new Error("No key returned from keybase for #{username}"), null) if not obj.startsWith("-----BEGIN PGP PUBLIC KEY BLOCK-----")
      callback(null, obj)
    )

  autocomplete: (query, callback) =>
    url = "/_/api/1.0/user/autocomplete.json"
    request({url: @baseUrl + url, form: {q: query}, headers: {'User-Agent': 'request'}, json: true}, (err, resp, obj) =>
      return callback(err, null) if err
      if obj.status?
        return callback(new Error(obj.status.desc), null) if obj.status.name != "OK"

      callback(null, obj.completions)
    )

  _keybaseRequest: (url, callback) =>
    return request({url: @baseUrl + url, headers: {'User-Agent': 'request'}, json: true}, callback)

  _regularToAutocomplete: (profile) ->
    # converts a keybase profile to the weird format used in the autocomplete
    # endpoint for backward compatability
    # (does NOT translate accounts - e.g. twitter, github - yet)
    # TODO this should be the other way around
    cleanedProfile = {components: {}}
    cleanedProfile.thumbnail = null
    if profile.pictures?.primary?
      cleanedProfile.thumbnail = profile.pictures.primary.url
    safe_name = if profile.profile? then profile.profile.full_name else ""
    cleanedProfile.components = {full_name: {val: safe_name }, username: {val: profile.basics.username}}
    _.each(profile.proofs_summary.all, (connectedAccount) =>
      component = {}
      component[connectedAccount.proof_type] = {val: connectedAccount.nametag}
      cleanedProfile.components = _.extend(cleanedProfile.components, component)
    )
    return cleanedProfile

module.exports = new KeybaseAPI()
