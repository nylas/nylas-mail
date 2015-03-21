_ = require "underscore-plus"
moment = require "moment"
proxyquire = require "proxyquire"

CSON = require "season"
React = require "react/addons"
TestUtils = React.addons.TestUtils

{Thread,
 Contact,
 Actions,
 Message,
 Namespace,
 MessageStore,
 NamespaceStore,
 InboxTestUtils,
 ComponentRegistry} = require "inbox-exports"

ComposerItem = React.createClass
  render: -> <div></div>
  focus: ->

AttachmentItem = React.createClass
  render: -> <div></div>
  focus: ->

ParticipantsItem = React.createClass
  render: -> <div></div>
  focus: ->

MessageItem = proxyquire("../lib/message-item", {
  "./email-frame": React.createClass({render: -> <div></div>})
})

MessageList = proxyquire("../lib/message-list", {
  "./message-item": MessageItem
})

MessageParticipants = require "../lib/message-participants"

me = new Namespace(
  "name": "User One",
  "email": "user1@inboxapp.com"
  "provider": "inbox"
)
NamespaceStore._current = me

user_headers =
  id: null
  object: null
  namespace_id: null

user_1 = _.extend _.clone(user_headers),
  name: "User One"
  email: "user1@inboxapp.com"
user_2 = _.extend _.clone(user_headers),
  name: "User Two"
  email: "user2@inboxapp.com"
user_3 = _.extend _.clone(user_headers),
  name: "User Three"
  email: "user3@inboxapp.com"
user_4 = _.extend _.clone(user_headers),
  name: "User Four"
  email: "user4@inboxapp.com"
user_5 = _.extend _.clone(user_headers),
  name: "User Five"
  email: "user5@inboxapp.com"

testMessages = [
  (new Message).fromJSON({
    "id"   : "111",
    "from" : [ user_1 ],
    "to"   : [ user_2 ],
    "cc"   : [ user_3, user_4 ],
    "bcc"  : null,
    "body"      : "Body One",
    "date"      : 1415814587,
    "draft"     : false
    "files"     : [],
    "unread"    : false,
    "object"    : "message",
    "snippet"   : "snippet one...",
    "subject"   : "Subject One",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
  (new Message).fromJSON({
    "id"   : "222",
    "from" : [ user_2 ],
    "to"   : [ user_1 ],
    "cc"   : [ user_3, user_4 ],
    "bcc"  : null,
    "body"      : "Body Two",
    "date"      : 1415814587,
    "draft"     : false
    "files"     : [],
    "unread"    : false,
    "object"    : "message",
    "snippet"   : "snippet Two...",
    "subject"   : "Subject Two",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
  (new Message).fromJSON({
    "id"   : "333",
    "from" : [ user_3 ],
    "to"   : [ user_1 ],
    "cc"   : [ user_2, user_4 ],
    "bcc"  : [],
    "body"      : "Body Three",
    "date"      : 1415814587,
    "draft"     : false
    "files"     : [],
    "unread"    : false,
    "object"    : "message",
    "snippet"   : "snippet Three...",
    "subject"   : "Subject Three",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
  (new Message).fromJSON({
    "id"   : "444",
    "from" : [ user_4 ],
    "to"   : [ user_1 ],
    "cc"   : [],
    "bcc"  : [ user_5 ],
    "body"      : "Body Four",
    "date"      : 1415814587,
    "draft"     : false
    "files"     : [],
    "unread"    : false,
    "object"    : "message",
    "snippet"   : "snippet Four...",
    "subject"   : "Subject Four",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
  (new Message).fromJSON({
    "id"   : "555",
    "from" : [ user_1 ],
    "to"   : [ user_4 ],
    "cc"   : [],
    "bcc"  : [],
    "body"      : "Body Five",
    "date"      : 1415814587,
    "draft"     : false
    "files"     : [],
    "unread"    : false,
    "object"    : "message",
    "snippet"   : "snippet Five...",
    "subject"   : "Subject Five",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
]
draftMessages = [
  (new Message).fromJSON({
    "id"   : "666",
    "from" : [ user_1 ],
    "to"   : [ ],
    "cc"   : [ ],
    "bcc"  : null,
    "body"      : "Body One",
    "date"      : 1415814587,
    "draft"     : true
    "files"     : [],
    "unread"    : false,
    "object"    : "draft",
    "snippet"   : "draft snippet one...",
    "subject"   : "Draft One",
    "thread_id" : "thread_12345",
    "namespace_id" : "nsid"
  }),
]

test_thread = (new Thread).fromJSON({
  "id" : "thread_12345"
  "subject" : "Subject 12345"
})

describe "MessageList", ->
  beforeEach ->
    ComponentRegistry.register
      name: 'Composer'
      view: ComposerItem
    ComponentRegistry.register
      name: 'Participants'
      view: ParticipantsItem
    ComponentRegistry.register
      name: 'AttachmentComponent'
      view: AttachmentItem

    MessageStore._items = []
    MessageStore._threadId = null
    spyOn(MessageStore, "itemLocalIds").andCallFake ->
      {"666": "666"}
    spyOn(MessageStore, "itemsLoading").andCallFake ->
      false

    @message_list = TestUtils.renderIntoDocument(<MessageList />)
    @message_list_node = @message_list.getDOMNode()

  it "renders into the document", ->
    expect(TestUtils.isCompositeComponentWithType(@message_list,
           MessageList)).toBe true

  it "by default has zero children", ->
    items = TestUtils.scryRenderedComponentsWithType(@message_list,
            MessageItem)

    expect(items.length).toBe 0

  describe "Populated Message list", ->
    beforeEach ->
      MessageStore._items = testMessages
      MessageStore.trigger(MessageStore)
      @message_list.setState currentThread: test_thread

    it "renders all the correct number of messages", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              MessageItem)
      expect(items.length).toBe 5

    it "aggregates participants across all messages", ->
      expect(@message_list._threadParticipants().length).toBe 4
      expect(@message_list._threadParticipants()[0] instanceof Contact).toBe true

    it "displays lists of participants on the page", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              MessageParticipants)
      expect(items.length).toBe 5

    # We no longer do this (for now)
    # it "displays the thread participants on the page", ->
    #   items = TestUtils.scryRenderedComponentsWithType(@message_list,
    #           ParticipantsItem)
    #   expect(items.length).toBe 1

    it "focuses new composers when a draft is added", ->
      spyOn(@message_list, "_focusDraft")
      msgs = @message_list.state.messages

      @message_list.setState
        messages: msgs.concat(draftMessages)

      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)

      expect(items.length).toBe 1
      expect(@message_list._focusDraft).toHaveBeenCalledWith(items[0])

    it "doesn't focus if we're just navigating through messages", ->
      spyOn(@message_list, "scrollToMessage")
      @message_list.setState messages: draftMessages
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)
      expect(items.length).toBe 1
      composer = items[0]
      expect(@message_list.scrollToMessage).not.toHaveBeenCalled()


  describe "MessageList with draft", ->
    beforeEach ->
      MessageStore._items = testMessages.concat draftMessages
      MessageStore.trigger(MessageStore)
      @message_list.setState currentThread: test_thread

    it "renders the composer", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)
      expect(@message_list.state.messages.length).toBe 6
      expect(@message_list.state.Composer).toEqual ComposerItem
      expect(items.length).toBe 1

      expect(items.length).toBe 1
