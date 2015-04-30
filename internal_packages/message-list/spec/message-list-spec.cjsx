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

{InjectedComponent} = require 'ui-components'

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

m1 = (new Message).fromJSON({
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
})
m2 = (new Message).fromJSON({
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
})
m3 = (new Message).fromJSON({
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
})
m4 = (new Message).fromJSON({
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
})
m5 = (new Message).fromJSON({
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
})
testMessages = [m1, m2, m3, m4, m5]
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
    MessageStore._items = []
    MessageStore._threadId = null
    spyOn(MessageStore, "itemLocalIds").andCallFake ->
      {"666": "666"}
    spyOn(MessageStore, "itemsLoading").andCallFake ->
      false

    @message_list = TestUtils.renderIntoDocument(<MessageList />)
    @message_list_node = React.findDOMNode(@message_list)

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
      MessageStore._expandItemsToDefault()
      MessageStore.trigger(MessageStore)
      @message_list.setState currentThread: test_thread

    it "renders all the correct number of messages", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              MessageItem)
      expect(items.length).toBe 5

    it "renders the correct number of expanded messages", ->
      msgs = TestUtils.scryRenderedDOMComponentsWithClass(@message_list, "message-item-wrap collapsed")
      expect(msgs.length).toBe 4

    it "aggregates participants across all messages", ->
      expect(@message_list._threadParticipants().length).toBe 4
      expect(@message_list._threadParticipants()[0] instanceof Contact).toBe true

    it "displays lists of participants on the page", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              MessageParticipants)
      expect(items.length).toBe 1

    it "focuses new composers when a draft is added", ->
      spyOn(@message_list, "_focusDraft")
      msgs = @message_list.state.messages

      @message_list.setState
        messages: msgs.concat(draftMessages)

      expect(@message_list._focusDraft).toHaveBeenCalled()
      expect(@message_list._focusDraft.mostRecentCall.args[0].props.exposedProps.localId).toEqual(draftMessages[0].id)

    it "doesn't focus if we're just navigating through messages", ->
      spyOn(@message_list, "scrollToMessage")
      @message_list.setState messages: draftMessages
      items = TestUtils.scryRenderedComponentsWithTypeAndProps(@message_list, InjectedComponent, matching: {role:"Composer"})
      expect(items.length).toBe 1
      composer = items[0]
      expect(@message_list.scrollToMessage).not.toHaveBeenCalled()


  describe "MessageList with draft", ->
    beforeEach ->
      MessageStore._items = testMessages.concat draftMessages
      MessageStore.trigger(MessageStore)
      @message_list.setState currentThread: test_thread

    it "renders the composer", ->
      items = TestUtils.scryRenderedComponentsWithTypeAndProps(@message_list, InjectedComponent, matching: {role:"Composer"})
      expect(@message_list.state.messages.length).toBe 6
      expect(items.length).toBe 1

      expect(items.length).toBe 1

  describe "reply type", ->
    it "prompts for a reply when there's only one participant", ->
      MessageStore._items = [m3, m5]
      MessageStore.trigger()
      @message_list.setState currentThread: test_thread
      expect(@message_list._replyType()).toBe "reply"
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@message_list, "footer-reply-area")
      expect(cs.length).toBe 1

    it "prompts for a reply-all when there's more then one participant", ->
      MessageStore._items = [m5, m3]
      MessageStore.trigger()
      @message_list.setState currentThread: test_thread
      expect(@message_list._replyType()).toBe "reply-all"
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@message_list, "footer-reply-area")
      expect(cs.length).toBe 1

    it "hides the reply type if the last message is a draft", ->
      MessageStore._items = [m5, m3, draftMessages[0]]
      MessageStore.trigger()
      @message_list.setState currentThread: test_thread
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@message_list, "footer-reply-area")
      expect(cs.length).toBe 0
