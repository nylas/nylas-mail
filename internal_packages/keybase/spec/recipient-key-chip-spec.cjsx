{React, ReactTestUtils, DraftStore, Contact} = require 'nylas-exports'
pgp = require 'kbpgp'

RecipientKeyChip = require '../lib/recipient-key-chip'
PGPKeyStore = require '../lib/pgp-key-store'

describe "DecryptMessageButton", ->
  beforeEach ->
    @contact = new Contact({email: "test@example.com"})
    @component = ReactTestUtils.renderIntoDocument(
      <RecipientKeyChip contact=@contact />
    )

  it "should render into the page", ->
    expect(@component).toBeDefined()

  it "should have a displayName", ->
    expect(RecipientKeyChip.displayName).toBe('RecipientKeyChip')

  xit "should indicate when a recipient has a PGP key available", ->
    spyOn(PGPKeyStore, "pubKeys").andCallFake((address) =>
      return [{'key':0}])
    key = PGPKeyStore.pubKeys(@contact.email)
    expect(key).toBeDefined()

    # TODO these calls crash the tester because they require a call to getKeyContents
    expect(@component.refs.keyIcon).toBeDefined()
    expect(@component.refs.noKeyIcon).not.toBeDefined()

  xit "should indicate when a recipient does not have a PGP key available", ->
    component = ReactTestUtils.renderIntoDocument(
      <RecipientKeyChip contact=@contact />
    )

    key = PGPKeyStore.pubKeys(@contact.email)
    expect(key).toEqual([])

    # TODO these calls crash the tester because they require a call to getKeyContents
    expect(component.refs.keyIcon).not.toBeDefined()
    expect(component.refs.noKeyIcon).toBeDefined()
