_ = require "underscore"
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
 DraftStore,
 MessageStore,
 NamespaceStore,
 NylasTestUtils,
 ComponentRegistry} = require "nylas-exports"

{InjectedComponent} = require 'nylas-component-kit'

MessageItem = proxyquire("../lib/message-item", {
  "./email-frame": React.createClass({render: -> <div></div>})
})

MessageList = proxyquire("../lib/message-list", {
  "./message-item": MessageItem
})

MessageParticipants = require "../lib/message-participants"

me = new Namespace
  name: "User One",
  emailAddress: "user1@nylas.com"
  provider: "inbox"
NamespaceStore._current = me

user_1 = new Contact
  name: "User One"
  email: "user1@nylas.com"
user_2 = new Contact
  name: "User Two"
  email: "user2@nylas.com"
user_3 = new Contact
  name: "User Three"
  email: "user3@nylas.com"
user_4 = new Contact
  name: "User Four"
  email: "user4@nylas.com"
user_5 = new Contact
  name: "User Five"
  email: "user5@nylas.com"

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

    @messageList = TestUtils.renderIntoDocument(<MessageList />)
    @messageList_node = React.findDOMNode(@messageList)

  it "renders into the document", ->
    expect(TestUtils.isCompositeComponentWithType(@messageList,
           MessageList)).toBe true

  it "by default has zero children", ->
    items = TestUtils.scryRenderedComponentsWithType(@messageList,
            MessageItem)

    expect(items.length).toBe 0

  describe "Populated Message list", ->
    beforeEach ->
      MessageStore._items = testMessages
      MessageStore._expandItemsToDefault()
      MessageStore.trigger(MessageStore)
      @messageList.setState currentThread: test_thread

      NylasTestUtils.loadKeymap("keymaps/base")

    it "renders all the correct number of messages", ->
      items = TestUtils.scryRenderedComponentsWithType(@messageList,
              MessageItem)
      expect(items.length).toBe 5

    it "renders the correct number of expanded messages", ->
      msgs = TestUtils.scryRenderedDOMComponentsWithClass(@messageList, "message-item-wrap collapsed")
      expect(msgs.length).toBe 4

    it "displays lists of participants on the page", ->
      items = TestUtils.scryRenderedComponentsWithType(@messageList,
              MessageParticipants)
      expect(items.length).toBe 1

    it "toggles star on a thread if 's' is pressed", ->
      spyOn(@messageList, "_onStar")
      NylasTestUtils.keyPress("s", document.body)
      expect(@messageList._onStar).toHaveBeenCalled()

    it "focuses new composers when a draft is added", ->
      spyOn(@messageList, "_focusDraft")
      msgs = @messageList.state.messages

      @messageList.setState
        messages: msgs.concat(draftMessages)

      expect(@messageList._focusDraft).toHaveBeenCalled()
      expect(@messageList._focusDraft.mostRecentCall.args[0].props.exposedProps.localId).toEqual(draftMessages[0].id)

  describe "MessageList with draft", ->
    beforeEach ->
      MessageStore._items = testMessages.concat draftMessages
      MessageStore.trigger(MessageStore)
      spyOn(@messageList, "_focusDraft")
      @messageList.setState(currentThread: test_thread)

    it "renders the composer", ->
      items = TestUtils.scryRenderedComponentsWithTypeAndProps(@messageList, InjectedComponent, matching: {role:"Composer"})
      expect(@messageList.state.messages.length).toBe 6
      expect(items.length).toBe 1

    it "doesn't focus on initial load", ->
      expect(@messageList._focusDraft).not.toHaveBeenCalled()

  describe "reply type", ->
    it "prompts for a reply when there's only one participant", ->
      MessageStore._items = [m3, m5]
      MessageStore.trigger()
      @messageList.setState currentThread: test_thread
      expect(@messageList._replyType()).toBe "reply"
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@messageList, "footer-reply-area")
      expect(cs.length).toBe 1

    it "prompts for a reply-all when there's more then one participant", ->
      MessageStore._items = [m5, m3]
      MessageStore.trigger()
      @messageList.setState currentThread: test_thread
      expect(@messageList._replyType()).toBe "reply-all"
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@messageList, "footer-reply-area")
      expect(cs.length).toBe 1

    it "hides the reply type if the last message is a draft", ->
      MessageStore._items = [m5, m3, draftMessages[0]]
      MessageStore.trigger()
      @messageList.setState currentThread: test_thread
      cs = TestUtils.scryRenderedDOMComponentsWithClass(@messageList, "footer-reply-area")
      expect(cs.length).toBe 0

  describe "reply behavior (_createReplyOrUpdateExistingDraft)", ->
    beforeEach ->
      @messageList.setState(currentThread: test_thread)

    it "should throw an exception unless you provide `reply` or `reply-all`", ->
      expect( => @messageList._createReplyOrUpdateExistingDraft('lala')).toThrow()

    describe "when there is already a draft at the bottom of the thread", ->
      beforeEach ->
        @replyToMessage = new Message
          id: "reply-id",
          threadId: test_thread.id
          date: new Date()
        @draft = new Message
          id: "666",
          draft: true,
          date: new Date()
          replyToMessage: @replyToMessage.id

        spyOn(@messageList, '_focusDraft')
        spyOn(@replyToMessage, 'participantsForReplyAll').andCallFake ->
          {to: [user_3], cc: [user_2, user_4] }
        spyOn(@replyToMessage, 'participantsForReply').andCallFake ->
          {to: [user_3], cc: [] }

        MessageStore._items = [@replyToMessage, @draft]
        MessageStore.trigger()
        @messageList.setState(currentThread: test_thread)

        @sessionStub =
          draft: => @draft
          changes:
            add: jasmine.createSpy('session.changes.add')
        spyOn(DraftStore, 'sessionForLocalId').andCallFake =>
          Promise.resolve(@sessionStub)

      it "should not fire a composer action", ->
        spyOn(Actions, 'composeReplyAll')
        @messageList._createReplyOrUpdateExistingDraft('reply-all')
        advanceClock()
        expect(Actions.composeReplyAll).not.toHaveBeenCalled()

      it "should focus the existing draft", ->
        @messageList._createReplyOrUpdateExistingDraft('reply-all')
        advanceClock()
        expect(@messageList._focusDraft).toHaveBeenCalled()

      describe "when reply-all is passed", ->
        it "should add missing participants", ->
          @draft.to = [ user_3 ]
          @draft.cc = []
          @messageList._createReplyOrUpdateExistingDraft('reply-all')
          advanceClock()
          expect(@sessionStub.changes.add).toHaveBeenCalledWith({to: [user_3], cc: [user_2, user_4]})

        it "should not blow away other participants who have been added to the draft", ->
          user_random_a = new Contact(email: 'other-guy-a@gmail.com')
          user_random_b = new Contact(email: 'other-guy-b@gmail.com')
          @draft.to = [ user_3, user_random_a ]
          @draft.cc = [ user_random_b ]
          @messageList._createReplyOrUpdateExistingDraft('reply-all')
          advanceClock()
          expect(@sessionStub.changes.add).toHaveBeenCalledWith({to: [user_3, user_random_a], cc: [user_random_b, user_2, user_4]})

      describe "when reply is passed", ->
        it "should remove participants present in the reply-all participant set and not in the reply set", ->
          @draft.to = [ user_3 ]
          @draft.cc = [ user_2, user_4 ]
          @messageList._createReplyOrUpdateExistingDraft('reply')
          advanceClock()
          expect(@sessionStub.changes.add).toHaveBeenCalledWith({to: [user_3], cc: []})

        it "should not blow away other participants who have been added to the draft", ->
          user_random_a = new Contact(email: 'other-guy-a@gmail.com')
          user_random_b = new Contact(email: 'other-guy-b@gmail.com')
          @draft.to = [ user_3, user_random_a ]
          @draft.cc = [ user_2, user_4, user_random_b ]
          @messageList._createReplyOrUpdateExistingDraft('reply')
          advanceClock()
          expect(@sessionStub.changes.add).toHaveBeenCalledWith({to: [user_3, user_random_a], cc: [user_random_b]})

    describe "when there is not an existing draft at the bottom of the thread", ->
      beforeEach ->
        MessageStore._items = [m5, m3]
        MessageStore.trigger()
        @messageList.setState(currentThread: test_thread)

      it "should fire a composer action based on the reply type", ->
        spyOn(Actions, 'composeReplyAll')
        @messageList._createReplyOrUpdateExistingDraft('reply-all')
        expect(Actions.composeReplyAll).toHaveBeenCalledWith(thread: test_thread, message: m3)

        spyOn(Actions, 'composeReply')
        @messageList._createReplyOrUpdateExistingDraft('reply')
        expect(Actions.composeReply).toHaveBeenCalledWith(thread: test_thread, message: m3)

  describe "Message minification", ->
    beforeEach ->
      @messageList.MINIFY_THRESHOLD = 3
      @messageList.setState minified: true
      @messages = [
        {id: 'a'}, {id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}, {id: 'f'}, {id: 'g'}
      ]

    it "ignores the first message if it's collapsed", ->
      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: false, f: false, g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}]
        },
        {id: 'f'},
        {id: 'g'}
      ]

    it "ignores the first message if it's expanded", ->
      @messageList.setState messagesExpandedState:
        a: "default", b: false, c: false, d: false, e: false, f: false, g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}]
        },
        {id: 'f'},
        {id: 'g'}
      ]

    it "doesn't minify the last collapsed message", ->
      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: false, f: "default", g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}]
        },
        {id: 'e'},
        {id: 'f'},
        {id: 'g'}
      ]

    it "allows explicitly expanded messages", ->
      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: false, f: "explicit", g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}]
        },
        {id: 'f'},
        {id: 'g'}
      ]

    it "doesn't minify if the threshold isn't reached", ->
      @messageList.setState messagesExpandedState:
        a: false, b: "default", c: false, d: "default", e: false, f: "default", g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {id: 'b'},
        {id: 'c'},
        {id: 'd'},
        {id: 'e'},
        {id: 'f'},
        {id: 'g'}
      ]

    it "doesn't minify if the threshold isn't reached due to the rule about not minifying the last collapsed messages", ->
      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: "default", f: "default", g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {id: 'b'},
        {id: 'c'},
        {id: 'd'},
        {id: 'e'},
        {id: 'f'},
        {id: 'g'}
      ]

    it "minifies at the threshold if the message is explicitly expanded", ->
      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: "explicit", f: "default", g: "default"

      out = @messageList._messagesWithMinification(@messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}]
        },
        {id: 'e'},
        {id: 'f'},
        {id: 'g'}
      ]

    it "can have multiple minification blocks", ->
      messages = [
        {id: 'a'}, {id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}, {id: 'f'},
        {id: 'g'}, {id: 'h'}, {id: 'i'}, {id: 'j'}, {id: 'k'}, {id: 'l'}
      ]

      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: false, f: "default",
        g: false, h: false, i: false, j: false, k: false, l: "default"

      out = @messageList._messagesWithMinification(messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}]
        },
        {id: 'e'},
        {id: 'f'},
        {
          type: "minifiedBundle"
          messages: [{id: 'g'}, {id: 'h'}, {id: 'i'}, {id: 'j'}]
        },
        {id: 'k'},
        {id: 'l'}
      ]

    it "can have multiple minification blocks next to explicitly expanded messages", ->
      messages = [
        {id: 'a'}, {id: 'b'}, {id: 'c'}, {id: 'd'}, {id: 'e'}, {id: 'f'},
        {id: 'g'}, {id: 'h'}, {id: 'i'}, {id: 'j'}, {id: 'k'}, {id: 'l'}
      ]

      @messageList.setState messagesExpandedState:
        a: false, b: false, c: false, d: false, e: "explicit", f: "default",
        g: false, h: false, i: false, j: false, k: "explicit", l: "default"

      out = @messageList._messagesWithMinification(messages)
      expect(out).toEqual [
        {id: 'a'},
        {
          type: "minifiedBundle"
          messages: [{id: 'b'}, {id: 'c'}, {id: 'd'}]
        },
        {id: 'e'},
        {id: 'f'},
        {
          type: "minifiedBundle"
          messages: [{id: 'g'}, {id: 'h'}, {id: 'i'}, {id: 'j'}]
        },
        {id: 'k'},
        {id: 'l'}
      ]
