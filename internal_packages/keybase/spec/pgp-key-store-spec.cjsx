{React, ReactTestUtils, DraftStore, Message} = require 'nylas-exports'
pgp = require 'kbpgp'
_ = require 'underscore'
fs = require 'fs'

Identity = require '../lib/identity'
PGPKeyStore = require '../lib/pgp-key-store'

describe "PGPKeyStore", ->
  beforeEach ->
    @TEST_KEY = """-----BEGIN PGP PRIVATE KEY BLOCK-----
      Version: GnuPG v1

      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
      217s2OKjpJqtpHPf2vY=
      =UY7Y
      -----END PGP PRIVATE KEY BLOCK-----"""

    # mock getKeyContents to get rid of all the fs.readFiles
    spyOn(PGPKeyStore, "getKeyContents").andCallFake( ({key, passphrase, callback}) =>
      data = @TEST_KEY
      pgp.KeyManager.import_from_armored_pgp {
        armored: data
      }, (err, km) =>
        expect(err).toEqual(null)
        if km.is_pgp_locked()
          expect(passphrase).toBeDefined()
          km.unlock_pgp { passphrase: passphrase }, (err) =>
            expect(err).toEqual(null)
        key.key = km
        key.setTimeout()
        if callback?
          callback()
    )

    # define an encrypted and an unencrypted message
    @unencryptedMsg = new Message({clientId: 'test', subject: 'Subject', body: '<p>Body</p>'})
    body = """-----BEGIN PGP MESSAGE-----
    Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

    wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
    =1aPN
    -----END PGP MESSAGE-----"""
    @encryptedMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

    # blow away the saved identities and set up a test pub/priv keypair
    PGPKeyStore._identities = {}
    pubIdent = new Identity({
      addresses: ["benbitdiddle@icloud.com"]
      isPriv: false
    })
    PGPKeyStore._identities[pubIdent.clientId] = pubIdent
    privIdent = new Identity({
      addresses: ["benbitdiddle@icloud.com"]
      isPriv: true
    })
    PGPKeyStore._identities[privIdent.clientId] = privIdent

  describe "when handling private keys", ->
    it 'should be able to retrieve and unlock a private key', ->
      expect(PGPKeyStore.privKeys().some((cv, index, array) =>
        cv.hasOwnProperty("key"))).toBeFalsey
      key = PGPKeyStore.privKeys(address: "benbitdiddle@icloud.com", timed: false)[0]
      PGPKeyStore.getKeyContents(key: key, passphrase: "", callback: =>
        expect(PGPKeyStore.privKeys({timed: false}).some((cv, index, array) =>
          cv.hasOwnProperty("key"))).toBeTruthy
      )

    it 'should not return a private key after its timeout has passed', ->
      expect(PGPKeyStore.privKeys({address: "benbitdiddle@icloud.com", timed: false}).length).toEqual(1)
      PGPKeyStore.privKeys({address: "benbitdiddle@icloud.com", timed: false})[0].timeout = Date.now() - 5
      expect(PGPKeyStore.privKeys(address: "benbitdiddle@icloud.com", timed: true).length).toEqual(0)
      PGPKeyStore.privKeys({address: "benbitdiddle@icloud.com", timed: false})[0].setTimeout()

    it 'should only return the key(s) corresponding to a supplied email address', ->
      expect(PGPKeyStore.privKeys(address: "wrong@example.com", timed: true).length).toEqual(0)

    it 'should return all private keys when an address is not supplied', ->
      expect(PGPKeyStore.privKeys({timed: false}).length).toEqual(1)

    it 'should update an existing key when it is unlocked, not add a new one', ->
      timeout = PGPKeyStore.privKeys({address: "benbitdiddle@icloud.com", timed: false})[0].timeout
      PGPKeyStore.getKeyContents(key: PGPKeyStore.privKeys({timed: false})[0], passphrase: "", callback: =>
        # expect no new keys to have been added
        expect(PGPKeyStore.privKeys({timed: false}).length).toEqual(1)
        # make sure the timeout is updated
        expect(timeout < PGPKeyStore.privKeys({address: "benbitdiddle@icloud.com", timed: false}).timeout)
      )

  describe "when decrypting messages", ->
    xit 'should be able to decrypt a message', ->
      # TODO for some reason, the pgp.unbox has a problem with the message body
      runs( =>
        spyOn(PGPKeyStore, 'trigger')
        PGPKeyStore.getKeyContents(key: PGPKeyStore.privKeys({timed: false})[0], passphrase: "", callback: =>
          PGPKeyStore.decrypt(@encryptedMsg)
        )
      )
      waitsFor((=> PGPKeyStore.trigger.callCount > 0), 'message to decrypt')
      runs( =>
        expect(_.findWhere(PGPKeyStore._msgCache,
               {clientId: @encryptedMsg.clientId})).toExist()
      )

    it 'should be able to handle an unencrypted message', ->
      PGPKeyStore.decrypt(@unencryptedMsg)
      expect(_.findWhere(PGPKeyStore._msgCache,
             {clientId: @unencryptedMsg.clientId})).not.toBeDefined()

    it 'should be able to tell when a message has no encrypted component', ->
      expect(PGPKeyStore.hasEncryptedComponent(@unencryptedMsg)).not
      expect(PGPKeyStore.hasEncryptedComponent(@encryptedMsg))

    it 'should be able to handle a message with no BEGIN PGP MESSAGE block', ->
      body = """Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

      wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
      =1aPN
      -----END PGP MESSAGE-----"""
      badMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

      PGPKeyStore.getKeyContents(key: PGPKeyStore.privKeys({timed: false})[0], passphrase: "", callback: =>
        PGPKeyStore.decrypt(badMsg)
        expect(_.findWhere(PGPKeyStore._msgCache,
               {clientId: badMsg.clientId})).not.toBeDefined()
      )

    it 'should be able to handle a message with no END PGP MESSAGE block', ->
      body = """-----BEGIN PGP MESSAGE-----
      Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

      wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
      =1aPN"""
      badMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

      PGPKeyStore.getKeyContents(key: PGPKeyStore.privKeys({timed: false})[0], passphrase: "", callback: =>
        PGPKeyStore.decrypt(badMsg)
        expect(_.findWhere(PGPKeyStore._msgCache,
               {clientId: badMsg.clientId})).not.toBeDefined()
      )

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

    it "should immediately return a pre-cached key", ->
      expect(PGPKeyStore.pubKeys('benbitdiddle@icloud.com').length).toEqual(1)
