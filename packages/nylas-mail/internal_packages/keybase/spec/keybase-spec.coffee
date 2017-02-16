kb = require '../lib/keybase'

xdescribe "keybase lib", ->
  # TODO stub keybase calls?
  it "should be able to fetch an account by username", ->
    @them = null
    runs( =>
      kb.getUser('dakota', 'usernames', (err, them) =>
        @them = them
      )
    )
    waitsFor((=> @them != null), 2000)
    runs( =>
      expect(@them?[0].components.username.val).toEqual("dakota")
    )

  it "should be able to fetch an account by key fingerprint", ->
    @them = null
    runs( =>
      kb.getUser('7FA5A43BBF2BAD1845C8D0E8145FCCD989968E3B', 'key_fingerprint', (err, them) =>
        @them = them
      )
    )
    waitsFor((=> @them != null), 2000)
    runs( =>
      expect(@them?[0].components.username.val).toEqual("dakota")
    )

  it "should be able to fetch a user's key", ->
    @key = null
    runs( =>
      kb.getKey('dakota', (error, key) =>
        @key = key
      )
    )
    waitsFor((=> @key != null), 2000)
    runs( =>
      expect(@key?.startsWith('-----BEGIN PGP PUBLIC KEY BLOCK-----'))
    )

  it "should be able to return an autocomplete query", ->
    @completions = null
    runs( =>
      kb.autocomplete('dakota', (error, completions) =>
        @completions = completions
      )
    )
    waitsFor((=> @completions != null), 2000)
    runs( =>
      expect(@completions[0].components.username.val).toEqual("dakota")
    )
