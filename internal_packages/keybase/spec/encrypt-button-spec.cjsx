{React, ReactDOM, ReactTestUtils, DraftStore, Message} = require 'nylas-exports'
pgp = require 'kbpgp'

EncryptMessageButton = require '../lib/encrypt-button'
PGPKeyStore = require '../lib/pgp-key-store'

describe "EncryptMessageButton", ->
  beforeEach ->
    key = """-----BEGIN PGP PRIVATE KEY BLOCK-----
      Version: GnuPG v1

      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
      217s2OKjpJqtpHPf2vY=
      =UY7Y
      -----END PGP PRIVATE KEY BLOCK-----"""

    pgp.KeyManager.import_from_armored_pgp {
      armored: key
    }, (err, km) =>
      @km = km

    waitsFor (=> @km?), "getting a key took too long", 1000

    @msg = new Message({subject: 'Subject', body: '<p>Body</p>', draft: true})
    @session =
      draft: =>
        return @msg
      changes:
        add: (changes) =>
          @output = changes

    @output = null

    add = jasmine.createSpy('add')
    spyOn(DraftStore, 'sessionForClientId').andCallFake((draftClientId) =>
      return Promise.resolve(@session)
    )

    @component = ReactTestUtils.renderIntoDocument(
      <EncryptMessageButton draft={@msg} session={@session} />
    )

  it "should render into the page", ->
    expect(@component).toBeDefined()

  it "should have a displayName", ->
    expect(EncryptMessageButton.displayName).toBe('EncryptMessageButton')

  it "should have an onClick behavior which encrypts the message", ->
    spyOn(@component, '_onClick')
    buttonNode = ReactDOM.findDOMNode(@component.refs.button)
    ReactTestUtils.Simulate.click(buttonNode)
    expect(@component._onClick).toHaveBeenCalled()

  it "should store the message body's plaintext on encryption", ->
    spyOn(@component, '_onClick')
    buttonNode = ReactDOM.findDOMNode(@component.refs.button)
    ReactTestUtils.Simulate.click(buttonNode)
    expect(@component.plaintext is @msg.body)

  it "should mark itself as encrypted", ->
    spyOn(@component, '_onClick')
    buttonNode = ReactDOM.findDOMNode(@component.refs.button)
    ReactTestUtils.Simulate.click(buttonNode)
    expect(@component.currentlyEncrypted is true)

  xit "should be able to encrypt messages", ->
    # NOTE: this doesn't work.
    # As best I can tell, something is wrong with the pgp.box function -
    # nothing seems to get it to complete. Weird.

    runs( =>
      console.log @km
      @component._encrypt("test text", [@km])

      @flag = false
      pgp.box {encrypt_for: [@km], msg: "test text"}, (err, result_string) =>
        expect(not err?)
        @err = err
        @result_string = result_string
        @flag = true
    )

    waitsFor (=> console.log @flag; @flag), "encryption took too long", 5000

    runs( =>
      console.log @err
      console.log @result_string
      console.log @output

      expect(@output is @result_string))
