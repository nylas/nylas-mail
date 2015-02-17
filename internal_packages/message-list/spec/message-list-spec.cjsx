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

MessageItem = proxyquire("../lib/message-item.cjsx", {
  "./email-frame": React.createClass({render: -> <div></div>})
})

MessageList = proxyquire("../lib/message-list.cjsx", {
  "./message-item.cjsx": MessageItem
})

ComposerItem = React.createClass
  render: -> <div></div>
  focus: ->
ComponentRegistry.register
  name: 'Composer'
  view: ComposerItem

MessageParticipants = require "../lib/message-participants.cjsx"
ThreadParticipants = require "../lib/thread-participants.cjsx"

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
  _resetMessageStore = ->
    MessageStore._items = []
    MessageStore._threadId = null
    spyOn(MessageStore, "itemLocalIds").andCallFake ->
      {"666": "666"}

  beforeEach ->
    _resetMessageStore()
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
      @message_list.setState current_thread: test_thread

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

    it "displays the thread participants on the page", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ThreadParticipants)
      expect(items.length).toBe 1

    it "focuses new composers when a draft is added", ->
      spyOn(@message_list, "_focusRef")
      msgs = @message_list.state.messages
      msgs = msgs.concat(draftMessages)
      @message_list.setState messages: msgs
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)
      expect(items.length).toBe 1
      composer = items[0]
      expect(@message_list._focusRef).toHaveBeenCalledWith(composer)

    it "doesn't focus if we're just navigating through messages", ->
      spyOn(@message_list, "_focusRef")
      @message_list.setState messages: draftMessages
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)
      expect(items.length).toBe 1
      composer = items[0]
      expect(@message_list._focusRef).not.toHaveBeenCalled()

    describe "Message", ->
      beforeEach ->
        items = TestUtils.scryRenderedComponentsWithType(@message_list,
                MessageItem)
        item = items.filter (message) -> message.props.message.id is "111"
        @message_item = item[0]
        @message_date = moment([2010, 1, 14, 15, 25, 50, 125])
        @message_item.props.message.date = moment(@message_date)

      it "finds the message by id", ->
        expect(@message_item.props.message.id).toBe "111"

      # test messsage time is 1415814587
      it "displays the time from messages LONG ago", ->
        spyOn(@message_item, "_today").andCallFake =>
          @message_date.add(2, 'years')
        expect(@message_item._timeFormat()).toBe "MMM D YYYY"

      it "displays the time and date from messages a bit ago", ->
        spyOn(@message_item, "_today").andCallFake =>
          @message_date.add(2, 'days')
        expect(@message_item._timeFormat()).toBe "MMM D, h:mm a"

      it "displays the time and date messages exactly a day ago", ->
        spyOn(@message_item, "_today").andCallFake =>
          @message_date.add(1, 'day')
        expect(@message_item._timeFormat()).toBe "MMM D, h:mm a"

      it "displays the time from messages yesterday with the day, even though it's less than 24 hours ago", ->
        spyOn(@message_item, "_today").andCallFake ->
          moment([2010, 1, 15, 2, 25, 50, 125])
        expect(@message_item._timeFormat()).toBe "MMM D, h:mm a"

      it "displays the time from messages recently", ->
        spyOn(@message_item, "_today").andCallFake =>
          @message_date.add(2, 'hours')
        expect(@message_item._timeFormat()).toBe "h:mm a"

  describe "MessageList with draft", ->
    beforeEach ->
      MessageStore._items = testMessages.concat draftMessages
      MessageStore.trigger(MessageStore)
      @message_list.setState current_thread: test_thread

    it "renders the composer", ->
      items = TestUtils.scryRenderedComponentsWithType(@message_list,
              ComposerItem)
      expect(@message_list.state.messages.length).toBe 6
      expect(@message_list.state.Composer).toEqual ComposerItem
      expect(items.length).toBe 1

      expect(items.length).toBe 1
