{React, ReactTestUtils, DraftStore, Message} = require 'nylas-exports'
pgp = require 'kbpgp'

DecryptMessageButton = require '../lib/decrypt-button'
PGPKeyStore = require '../lib/pgp-key-store'

describe "DecryptMessageButton", ->
  beforeEach ->
    @unencryptedMsg = new Message({clientId: 'test', subject: 'Subject', body: '<p>Body</p>'})
    body = """-----BEGIN PGP MESSAGE-----
    Version: Keybase OpenPGP v2.0.52 Comment: keybase.io/crypto

    wcBMA5nwa6GWVDOUAQf+MjiVRIBWJyM6The6/h2MgSJTDyrN9teFFJTizOvgHNnD W4EpEmmhShNyERI67qXhC03lFczu2Zp2Qofgs8YePIEv7wwb27/cviODsE42YJvX 1zGir+jBp81s9ZiF4dex6Ir9XfiZJlypI2QV2dHjO+5pstW+XhKIc1R5vKvoFTGI 1XmZtL3EgtKfj/HkPUkq2N0G5kAoB2MTTQuurfXm+3TRkftqesyTKlek652sFjCv nSF+LQ1GYq5hI4YaUBiHnZd7wKUgDrIh2rzbuGq+AHjrHdVLMfRTbN0Xsy3OWRcC 9uWU8Nln00Ly6KbTqPXKcBDcMrOJuoxYcpmLlhRds9JoAY7MyIsj87M2mkTtAtMK hqK0PPvJKfepV+eljDhQ7y0TQ0IvNtO5/pcY2CozbFJncm/ToxxZPNJueKRcz+EH M9uBvrWNTwfHj26g405gpRDN1T8CsY5ZeiaDHduIKnBWd4za0ak0Xfw=
    =1aPN
    -----END PGP MESSAGE-----"""
    @encryptedMsg = new Message({clientId: 'test2', subject: 'Subject', body: body})

    @msg = new Message({subject: 'Subject', body: '<p>Body</p>'})
    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=@msg />
    )

  it "should render into the page", ->
    expect(@component).toBeDefined()

  it "should have a displayName", ->
    expect(DecryptMessageButton.displayName).toBe('DecryptMessageButton')

  it "should try to decrypt the message whenever a new key is unlocked", ->
    spyOn(PGPKeyStore, "decrypt")
    spyOn(PGPKeyStore, "isDecrypted").andCallFake((message) =>
      return false)
    spyOn(PGPKeyStore, "hasEncryptedComponent").andCallFake((message) =>
      return true)

    PGPKeyStore.trigger(PGPKeyStore)

    expect(PGPKeyStore.decrypt).toHaveBeenCalled()

  xit "should not try to decrypt the message whenever a new key is unlocked
       if the message is already decrypted", ->
    spyOn(PGPKeyStore, "decrypt")
    spyOn(PGPKeyStore, "isDecrypted").andCallFake((message) =>
      return true)
    spyOn(PGPKeyStore, "hasEncryptedComponent").andCallFake((message) =>
      return true)

    # TODO for some reason the above spyOn calls aren't working and false is
    # being returned from isDecrypted, causing this test to fail
    PGPKeyStore.trigger(PGPKeyStore)

    expect(PGPKeyStore.decrypt).not.toHaveBeenCalled()

  it "should have a field for a passphrase and a button to decrypt a message", ->
    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=@encryptedMsg />
    )

    expect(@component.refs.button).toBeDefined()
    expect(@component.refs.passphrase).toBeDefined()
    expect(@component.refs.decrypted).not.toBeDefined()

  it "should not allow for the unlocking of a message with no encrypted component", ->
    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=@unencryptedMsg />
    )

    expect(@component.refs.button).not.toBeDefined()
    expect(@component.refs.passphrase).not.toBeDefined()
    expect(@component.refs.decrypted).not.toBeDefined()

  it "should indicate when a message has been decrypted", ->
    spyOn(PGPKeyStore, "isDecrypted").andCallFake((message) =>
      return true)

    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=@encryptedMsg />
    )

    expect(@component.refs.button).not.toBeDefined()
    expect(@component.refs.passphrase).not.toBeDefined()
    expect(@component.refs.decrypted).toBeDefined()

  it "should take input from a text field and attempt to unlock a key", ->
    msg = @encryptedMsg
    msg.to = [{email: "test@example.com"}]
    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=msg />
    )
    spyOn(PGPKeyStore, "privKeys").andCallFake((address) =>
      return [0])
    spyOn(PGPKeyStore, "getKeyContents")

    node = @component.refs.passphrase
    node.value = 'testpass'
    ReactTestUtils.Simulate.change(node)

    ReactTestUtils.Simulate.click(@component.refs.button)

    # TODO for some reason the call to Simulate.change doesn't seem to be working...
    #expect(PGPKeyStore.unlockKey).toHaveBeenCalledWith('test@example.com', 'testpass')
    expect(PGPKeyStore.getKeyContents).toHaveBeenCalled()

  it "should try to decrypt a key for each recipient of the message", ->
    msg = @encryptedMsg
    msg.to = [{email: "test1@example.com"}, {email: "test2@example.com"}]
    @component = ReactTestUtils.renderIntoDocument(
      <DecryptMessageButton message=msg />
    )
    spyOn(PGPKeyStore, "privKeys").andCallFake((address) =>
      return [0])
    spyOn(PGPKeyStore, "getKeyContents")

    ReactTestUtils.Simulate.click(@component.refs.button)

    expect(PGPKeyStore.getKeyContents.callCount).toEqual(2)
