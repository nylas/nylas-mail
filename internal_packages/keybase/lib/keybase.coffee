_ = require 'underscore'
request = require 'request'

class KeybaseAPI
  constructor: ->
    @baseUrl = "https://keybase.io"

  getUser: (key, keyType, cb) =>
    if not keyType in ['usernames', 'domain', 'twitter', 'github', 'reddit',
                       'hackernews', 'coinbase', 'key_fingerprint']
      console.error 'keyType must be a supported Keybase query type.'

    this._keybaseRequest("/_/api/1.0/user/lookup.json?#{keyType}=#{key}", (err, resp, obj) =>
      if err?
        console.error(err)
        cb(null)

      if obj.status.name != "OK"
        console.error obj.status.desc unless not obj.status.desc?
        cb(null)

      cb(_.map(obj.them, @_regularToAutocomplete))
    )

  getKey: (username, cb) =>
    request({url: @baseUrl + "/#{username}/key.asc", headers: {'User-Agent': 'request'}}, (err, resp, obj) =>
      if err?
        console.error(err)
        cb(null)

      cb(obj)
    )

  autocomplete: (query, cb) =>
    url = "/_/api/1.0/user/autocomplete.json"
    request({url: @baseUrl + url, form: {q: query}, headers: {'User-Agent': 'request'}, json: true}, (err, resp, obj) =>
      if err?
        console.error(err)
        cb(null)

      if obj.status.name != "OK"
        console.error obj.status.desc unless not obj.status.desc?
        cb(null)

      cb(obj.completions)
    )


  _keybaseRequest: (url, cb) =>
    return request({url: @baseUrl + url, headers: {'User-Agent': 'request'}, json: true}, cb)

  _regularToAutocomplete: (profile) ->
    # converts a keybase profile to the weird format used in the autocomplete
    # endpoint for backward compatability
    # (does NOT translate accounts - e.g. twitter, github - yet)
    # TODO this should be the other way around
    cleanedProfile = {components: {}}
    cleanedProfile.thumbnail = null
    if profile.pictures?.primary?
      cleanedProfile.thumbnail = profile.pictures.primary.url
    cleanedProfile.components = {username: {val: profile.basics.username}}
    return cleanedProfile

module.exports = new KeybaseAPI()
