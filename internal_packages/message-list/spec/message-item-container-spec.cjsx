React = require "react"
proxyquire = require("proxyquire").noPreserveCache()
ReactTestUtils = require('react-addons-test-utils')

{Thread,
 Message,
 ComponentRegistry,
 DraftStore} = require 'nylas-exports'

class StubMessageItem extends React.Component
  @displayName: "StubMessageItem"
  render: -> <span></span>

class StubComposer extends React.Component
  @displayName: "StubComposer"
  render: -> <span></span>

MessageItemContainer = proxyquire '../lib/message-item-container',
  "./message-item": StubMessageItem

testThread = new Thread(id: "t1", accountId: TEST_ACCOUNT_ID)
testClientId = "local-id"
testMessage = new Message(id: "m1", draft: false, unread: true, accountId: TEST_ACCOUNT_ID)
testDraft = new Message(id: "d1", draft: true, unread: true, accountId: TEST_ACCOUNT_ID)

describe 'MessageItemContainer', ->

  beforeEach ->
    @isSendingDraft = false
    spyOn(DraftStore, "isSendingDraft").andCallFake => @isSendingDraft
    ComponentRegistry.register(StubComposer, role: 'Composer')

  afterEach ->
    ComponentRegistry.register(StubComposer, role: 'Composer')

  renderContainer = (message) ->
    ReactTestUtils.renderIntoDocument(
      <MessageItemContainer thread={testThread}
                            message={message}
                            draftClientId={testClientId} />
    )

  it "shows composer if it's a draft", ->
    @isSendingDraft = false
    doc = renderContainer(testDraft)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc, StubComposer)
    expect(items.length).toBe 1

  it "renders a message if it's a draft that is sending", ->
    @isSendingDraft = true
    doc = renderContainer(testDraft)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc, StubMessageItem)
    expect(items.length).toBe 1
    expect(items[0].props.pending).toBe true

  it "renders a message if it's not a draft", ->
    @isSendingDraft = false
    doc = renderContainer(testMessage)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc, StubMessageItem)
    expect(items.length).toBe 1
