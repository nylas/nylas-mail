




return






moment = require "moment"
_ = require 'underscore'
CSON = require 'season'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
ReactTestUtils = _.extend ReactTestUtils, require "jasmine-react-helpers"

{Thread,
 Actions,
 Namespace,
 DatabaseStore,
 WorkspaceStore,
 NylasTestUtils,
 NamespaceStore,
 ComponentRegistry} = require "nylas-exports"
{ListTabular} = require 'nylas-component-kit'


ThreadStore = require "../lib/thread-store"
ThreadList = require "../lib/thread-list"

ParticipantsItem = React.createClass
  render: -> <div></div>

me = new Namespace(
  "name": "User One",
  "email": "user1@nylas.com"
  "provider": "inbox"
)
NamespaceStore._current = me

test_threads = -> [
  (new Thread).fromJSON({
    "id": "111",
    "object": "thread",
    "created_at": null,
    "updated_at": null,
    "namespace_id": "nsid",
    "snippet": "snippet 111",
    "subject": "Subject 111",
    "tags": [
      {
        "id": "unseen",
        "created_at": null,
        "updated_at": null,
        "name": "unseen"
      },
      {
        "id": "all",
        "created_at": null,
        "updated_at": null,
        "name": "all"
      },
      {
        "id": "inbox",
        "created_at": null,
        "updated_at": null,
        "name": "inbox"
      },
      {
        "id": "unread",
        "created_at": null,
        "updated_at": null,
        "name": "unread"
      },
      {
        "id": "attachment",
        "created_at": null,
        "updated_at": null,
        "name": "attachment"
      }
    ],
    "participants": [
      {
        "created_at": null,
        "updated_at": null,
        "name": "User One",
        "email": "user1@nylas.com"
      },
      {
        "created_at": null,
        "updated_at": null,
        "name": "User Two",
        "email": "user2@nylas.com"
      }
    ],
    "last_message_timestamp": 1415742036
  }),
  (new Thread).fromJSON({
    "id": "222",
    "object": "thread",
    "created_at": null,
    "updated_at": null,
    "namespace_id": "nsid",
    "snippet": "snippet 222",
    "subject": "Subject 222",
    "tags": [
      {
        "id": "unread",
        "created_at": null,
        "updated_at": null,
        "name": "unread"
      },
      {
        "id": "all",
        "created_at": null,
        "updated_at": null,
        "name": "all"
      },
      {
        "id": "unseen",
        "created_at": null,
        "updated_at": null,
        "name": "unseen"
      },
      {
        "id": "inbox",
        "created_at": null,
        "updated_at": null,
        "name": "inbox"
      }
    ],
    "participants": [
      {
        "created_at": null,
        "updated_at": null,
        "name": "User One",
        "email": "user1@nylas.com"
      },
      {
        "created_at": null,
        "updated_at": null,
        "name": "User Three",
        "email": "user3@nylas.com"
      }
    ],
    "last_message_timestamp": 1415741913
  }),
  (new Thread).fromJSON({
    "id": "333",
    "object": "thread",
    "created_at": null,
    "updated_at": null,
    "namespace_id": "nsid",
    "snippet": "snippet 333",
    "subject": "Subject 333",
    "tags": [
      {
        "id": "inbox",
        "created_at": null,
        "updated_at": null,
        "name": "inbox"
      },
      {
        "id": "all",
        "created_at": null,
        "updated_at": null,
        "name": "all"
      },
      {
        "id": "unseen",
        "created_at": null,
        "updated_at": null,
        "name": "unseen"
      }
    ],
    "participants": [
      {
        "created_at": null,
        "updated_at": null,
        "name": "User One",
        "email": "user1@nylas.com"
      },
      {
        "created_at": null,
        "updated_at": null,
        "name": "User Four",
        "email": "user4@nylas.com"
      }
    ],
    "last_message_timestamp": 1415741837
  })
]


cjsxSubjectResolver = (thread) ->
  <div>
    <span>Subject {thread.id}</span>
    <span className="snippet">Snippet</span>
  </div>

describe "ThreadList", ->

  Foo = React.createClass({render: -> <div>{@props.children}</div>})
  c1 = new ListTabular.Column
    name: "Name"
    flex: 1
    resolver: (thread) -> "#{thread.id} Test Name"
  c2 = new ListTabular.Column
    name: "Subject"
    flex: 3
    resolver: cjsxSubjectResolver
  c3 = new ListTabular.Column
    name: "Date"
    resolver: (thread) -> <Foo>{thread.id}</Foo>

  columns = [c1,c2,c3]

  beforeEach ->
    NylasTestUtils.loadKeymap("internal_packages/thread-list/keymaps/thread-list")
    spyOn(ThreadStore, "_onNamespaceChanged")
    spyOn(DatabaseStore, "findAll").andCallFake ->
      new Promise (resolve, reject) -> resolve(test_threads())
    spyOn(Actions, "archive")
    spyOn(Actions, "archiveAndNext")
    spyOn(Actions, "archiveAndPrevious")
    ReactTestUtils.spyOnClass(ThreadList, "_prepareColumns").andCallFake ->
      @_columns = columns

    ThreadStore._resetInstanceVars()

    ComponentRegistry.register
      name: 'Participants'
      view: ParticipantsItem

    @thread_list = ReactTestUtils.renderIntoDocument(
      <ThreadList />
    )

  it "renders into the document", ->
    expect(ReactTestUtils.isCompositeComponentWithType(@thread_list,
                                          ThreadList)).toBe true

  it "has the expected columns", ->
    expect(@thread_list._columns).toEqual columns

  it "by default has zero children", ->
    items = ReactTestUtils.scryRenderedComponentsWithType(@thread_list, ListTabular.Item)
    expect(items.length).toBe 0

  describe "when the workspace is in list mode", ->
    beforeEach ->
      spyOn(WorkspaceStore, "layoutMode").andReturn "list"
      @thread_list.setState focusedId: "t111"

    it "allows reply only when the sheet type is 'Thread'", ->
      spyOn(WorkspaceStore, "sheet").andCallFake -> {type: "Thread"}
      spyOn(Actions, "composeReply")
      @thread_list._onReply()
      expect(Actions.composeReply).toHaveBeenCalled()
      expect(@thread_list._actionInVisualScope()).toBe true

    it "doesn't reply only when the sheet type isnt 'Thread'", ->
      spyOn(WorkspaceStore, "sheet").andCallFake -> {type: "Root"}
      spyOn(Actions, "composeReply")
      @thread_list._onReply()
      expect(Actions.composeReply).not.toHaveBeenCalled()
      expect(@thread_list._actionInVisualScope()).toBe false

  describe "when the workspace is in split mode", ->
    beforeEach ->
      spyOn(WorkspaceStore, "layoutMode").andReturn "split"
      @thread_list.setState focusedId: "t111"

    it "allows reply and reply-all regardless of sheet type", ->
      spyOn(WorkspaceStore, "sheet").andCallFake -> {type: "anything"}
      spyOn(Actions, "composeReply")
      @thread_list._onReply()
      expect(Actions.composeReply).toHaveBeenCalled()
      expect(@thread_list._actionInVisualScope()).toBe true

  describe "Populated thread list", ->
    beforeEach ->
      view =
        loaded: -> true
        get: (i) -> test_threads()[i]
        count: -> test_threads().length
        setRetainedRange: ->
      ThreadStore._view = view
      ThreadStore._focusedId = null
      ThreadStore.trigger(ThreadStore)
      @thread_list_node = React.findDOMNode(@thread_list)
      spyOn(@thread_list, "setState").andCallThrough()

    it "renders all of the thread list items", ->
      advanceClock(100)
      items = ReactTestUtils.scryRenderedComponentsWithType(@thread_list, ListTabular.Item)
      expect(items.length).toBe(test_threads().length)
