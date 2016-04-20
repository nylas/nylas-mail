{React, ReactTestUtils, DraftStore, Message} = require 'nylas-exports'
pgp = require 'kbpgp'
_ = require 'underscore'

PGPKeyStore = require '../lib/pgp-key-store'

describe "PGPKeyStore", ->
  it 'performs setup for I/O tests', ->
    spyOn(PGPKeyStore, 'trigger')
    TEST_KEY = """-----BEGIN PGP PRIVATE KEY BLOCK-----
      Version: GnuPG v1

      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
      217s2OKjpJqtpHPf2vY=
      =UY7Y
      -----END PGP PRIVATE KEY BLOCK-----"""
    @TEST_KEY = TEST_KEY
    pubKeys = PGPKeyStore.pubKeys("benbitdiddle@icloud.com")
    if (pubKeys.length < 1)
      runs(=>
        PGPKeyStore.saveNewKey("benbitdiddle@icloud.com", TEST_KEY, isPub = true)
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 1000)
    privKeys = PGPKeyStore.privKeys(address: "benbitdiddle@icloud.com", timed: false)
    if (privKeys.length < 1)
      runs(=>
        PGPKeyStore.saveNewKey("benbitdiddle@icloud.com", TEST_KEY, isPub = false)
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 1000)

  beforeEach ->
    @unencryptedMsg = new Message({clientId: 'test', subject: 'Subject', body: '<p>Body</p>'})
    body = """-----BEGIN PGP MESSAGE-----
    Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

    wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
    =1aPN
    -----END PGP MESSAGE-----"""
    @encryptedMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

  describe "when handling private keys", ->
    it 'should be able to retrieve and unlock a private key', ->
      spyOn(PGPKeyStore, 'trigger')
      runs( =>
        expect(PGPKeyStore._pubKeys.some((cv, index, array) =>
          cv.hasOwnProperty("key"))).toBeFalsey
        key = PGPKeyStore.privKeys(address: "benbitdiddle@icloud.com", timed: false)[0]
        PGPKeyStore.getKeyContents(key: key, passphrase: "")
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0 ), 1000, 'a key to be fetched')
      runs( =>
        expect(PGPKeyStore._privKeys.some((cv, index, array) =>
          cv.hasOwnProperty("key"))).toBeTruthy
      )

    it 'should not return a private key after its timeout has passed', ->
      expect(PGPKeyStore._privKeys.length).toEqual(1)
      PGPKeyStore._privKeys[0].timeout = Date.now()
      expect(PGPKeyStore.privKeys(address: "benbitdiddle@icloud.com", timed: true).length).toEqual(0)
      PGPKeyStore._privKeys[0].timeout = Date.now() + (1000 * 30 * 60)

    it 'should only return the key(s) corresponding to a supplied email address', ->
      expect(PGPKeyStore.privKeys(address: "wrong@example.com", timed: true).length).toEqual(0)

    it 'should return all private keys when an address is not supplied', ->
      expect(PGPKeyStore.privKeys({}).length).toEqual(1)

    it 'should update instead of adding if a key is already unlocked', ->
      spyOn(PGPKeyStore, 'trigger')
      runs( =>
        @numkeys = PGPKeyStore._privKeys.length
        console.log PGPKeyStore._privKeys
        @timeout = _.find(PGPKeyStore._privKeys, (key) => "benbitdiddle@icloud.com" in key.addresses).timeout
        PGPKeyStore.getKeyContents(key: PGPKeyStore._privKeys[0], passphrase: "")
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 1000, "a key to be fetched")
      runs( =>
        # expect no new keys to have been added
        expect(PGPKeyStore._privKeys.length).toEqual(@numkeys)
        # make sure the timeout is updated
        expect(@timeout < _.findWhere(PGPKeyStore._privKeys, {address: "benbitdiddle@icloud.com"}).timeout)
      )

    it 'should be able to overwrite a saved key with a new one', ->
      spyOn(PGPKeyStore, '_displayError')
      spyOn(PGPKeyStore, 'trigger')
      runs( =>
        @numKeys = PGPKeyStore._pubKeys.length
        PGPKeyStore.saveKey("benbitdiddle@icloud.com", @TEST_KEY, isPub = true)
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 1000, 'key to write to disk')
      runs( =>
        # expect no errors
        expect(PGPKeyStore._displayError).not.toHaveBeenCalled()
        # expect the old key entry to have been updated (i.e. no more added)
        expect(PGPKeyStore._pubKeys.length).toEqual(@numKeys)
      )

  describe "when decrypting messages", ->
    xit 'should be able to decrypt a message', ->
      # TODO for some reason, the pgp.unbox has a problem with the message body
      runs( =>
        spyOn(PGPKeyStore, 'trigger')
        # TODO these are left over from a previous test... which is bad
        expect(PGPKeyStore._privKeys.length).toEqual(2)
        PGPKeyStore.decrypt(@encryptedMsg)
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 'message to decrypt')
      runs( =>
        expect(_.findWhere(PGPKeyStore._msgCache,
               {clientId: @encryptedMsg.clientId})).toExist()
      )

    it 'should be able to handle an unencrypted message', ->
      # TODO these are left over from a previous test... which is bad
      expect(PGPKeyStore._privKeys.length).toEqual(1)
      PGPKeyStore.decrypt(@unencryptedMsg)
      expect(_.findWhere(PGPKeyStore._msgCache,
             {clientId: @unencryptedMsg.clientId})).not.toExist()

    it 'should be able to tell when a message has no encrypted component', ->
      expect(PGPKeyStore.hasEncryptedComponent(@unencryptedMsg)).not
      expect(PGPKeyStore.hasEncryptedComponent(@encryptedMsg))

    it 'should be able to handle a message with no BEGIN PGP MESSAGE block', ->
      body = """Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

      wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
      =1aPN
      -----END PGP MESSAGE-----"""
      badMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

      # TODO these are left over from a previous test... which is bad
      expect(PGPKeyStore._privKeys.length).toEqual(1)
      PGPKeyStore.decrypt(badMsg)
      expect(_.findWhere(PGPKeyStore._msgCache,
             {clientId: badMsg.clientId})).not.toExist()

    it 'should be able to handle a message with no END PGP MESSAGE block', ->
      body = """-----BEGIN PGP MESSAGE-----
      Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

      wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
      =1aPN"""
      badMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

      # TODO these are left over from a previous test... which is bad
      expect(PGPKeyStore._privKeys.length).toEqual(1)
      PGPKeyStore.decrypt(badMsg)
      expect(_.findWhere(PGPKeyStore._msgCache,
             {clientId: badMsg.clientId})).not.toExist()

    it 'should not return a decrypted message which has timed out', ->
      PGPKeyStore._msgCache.push({clientId: "testID", body: "example body", timeout: Date.now()})

      msg = new Message({clientId: "testID"})
      expect(PGPKeyStore.getDecrypted(msg)).toEqual(null)

    it 'should return a decrypted message', ->
      timeout = Date.now() + (1000*60*60)
      PGPKeyStore._msgCache.push({clientId: "testID2", body: "example body", timeout: timeout})

      msg = new Message({clientId: "testID2", body: "example body"})
      expect(PGPKeyStore.getDecrypted(msg)).toEqual(msg.body)

  describe "when handling public keys", ->
    beforeEach ->
      spyOn(PGPKeyStore, 'trigger')

    it "should cache keys after fetching them", ->
      runs( =>
        key = PGPKeyStore.pubKeys("benbitdiddle@icloud.com")[0]
        # make sure we have the key metadata, but not an actual key yet
        expect(key.address).toEqual("benbitdiddle@icloud.com")
        expect(key.key).not.toBeDefined()
        # now go fetch the actual key
        PGPKeyStore.getKeyContents(key: key)
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 1000)
      runs( =>
        expect(PGPKeyStore._pubKeys.some((cv, index, array) =>
          cv.hasOwnProperty("key"))).toBeTruthy
      )

    it "should immediately return a pre-cached key", ->
      expect(PGPKeyStore.pubKeys('benbitdiddle@icloud.com').length).toEqual(1)
