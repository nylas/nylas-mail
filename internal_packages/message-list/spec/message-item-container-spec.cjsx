React = require "react/addons"
proxyquire = require("proxyquire").noPreserveCache()
ReactTestUtils = React.addons.TestUtils

{Thread,
 Message,
 DraftStore} = require 'nylas-exports'

class MessageItem extends React.Component
  @displayName: "StubMessageItem"
  render: -> <span></span>

MessageItemContainer = proxyquire '../lib/message-item-container',
  "./message-item": MessageItem

{InjectedComponent} = require 'nylas-component-kit'

testThread = new Thread(id: "t1")
testClientId = "local-id"
testMessage = new Message(id: "m1", draft: false, unread: true)
testDraft = new Message(id: "d1", draft: true, unread: true)

describe 'MessageItemContainer', ->

  beforeEach ->
    @isSendingDraft = false
    spyOn(DraftStore, "isSendingDraft").andCallFake => @isSendingDraft

  renderContainer = (message) ->
    ReactTestUtils.renderIntoDocument(
      <MessageItemContainer thread={testThread}
                            message={message}
                            draftClientId={testClientId} />
    )

  it "shows composer if it's a draft", ->
    @isSendingDraft = false
    doc = renderContainer(testDraft)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc,
            InjectedComponent)
    expect(items.length).toBe 1

  it "shows a pending message if it's a sending draft", ->
    @isSendingDraft = true
    doc = renderContainer(testDraft)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc,
            MessageItem)
    expect(items.length).toBe 1
    expect(items[0].props.pending).toBe true

  it "renders a message if it's not a draft", ->
    @isSendingDraft = false
    doc = renderContainer(testMessage)
    items = ReactTestUtils.scryRenderedComponentsWithType(doc,
            MessageItem)
    expect(items.length).toBe 1
