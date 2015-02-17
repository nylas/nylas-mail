_ = require "underscore-plus"
proxyquire = require "proxyquire"

React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

{Contact,
 Message,
 Namespace,
 DatabaseStore,
 InboxTestUtils,
 NamespaceStore} = require "inbox-exports"

u1 = new Contact(name: "Christine Spang", email: "spang@inboxapp.com")
u2 = new Contact(name: "Michael Grinich", email: "mg@inboxapp.com")
u3 = new Contact(name: "Evan Morikawa",   email: "evan@inboxapp.com")
u4 = new Contact(name: "Zoë Leiper",      email: "zip@inboxapp.com")
u5 = new Contact(name: "Ben Gotow",       email: "ben@inboxapp.com")
users = [u1, u2, u3, u4, u5]
NamespaceStore._current = new Namespace(
  {name: u1.name, provider: "inbox", emailAddress: u1.email})

reactStub = (className) ->
  React.createClass({render: -> <div className={className}>{@props.children}</div>})

textFieldStub = (className) ->
  React.createClass
    render: -> <div className={className}>{@props.children}</div>
    focus: ->

draftStoreProxyStub = (localId) ->
  listen: -> # noop
  draft: -> new Message()
  changes:
    add: ->
    commit: ->
    applyToModel: ->

searchContactStub = (email) ->
  _.filter(users, (u) u.email.toLowerCase() is email.toLowerCase())

ComposerView = proxyquire "../lib/composer-view.cjsx",
  "./file-uploads.cjsx": reactStub("file-uploads")
  "./draft-store-proxy": draftStoreProxyStub
  "./composer-participants.cjsx": reactStub("composer-participants")
  "./participants-text-field.cjsx": textFieldStub("")
  "inbox-exports":
    ContactStore:
      searchContacts: (email) -> searchContactStub
    ComponentRegistry:
      listen: -> ->
      findViewByName: (component) -> reactStub(component)
      findAllViewsByRole: (role) -> [reactStub('a'),reactStub('b')]

beforeEach ->
  # The NamespaceStore isn't set yet in the new window, populate it first.
  NamespaceStore.populateItems().then ->
    new Promise (resolve, reject) ->
      draft = new Message
        from: [NamespaceStore.current().me()]
        date: (new Date)
        draft: true
        namespaceId: NamespaceStore.current().id

      DatabaseStore.persistModel(draft).then ->
        DatabaseStore.localIdForModel(draft).then(resolve).catch(reject)
      .catch(reject)

describe "A blank composer view", ->
  beforeEach ->
    @composer = ReactTestUtils.renderIntoDocument(
      <ComposerView />
    )
    @composer.setState
      body: ""

  it 'should render into the document', ->
    expect(ReactTestUtils.isCompositeComponentWithType @composer, ComposerView).toBe true

  describe "testing keyboard inputs", ->
    beforeEach ->
      spyOn(@composer, "_sendDraft")
      InboxTestUtils.loadKeymap "internal_packages/composer/keymaps/composer.cson"

    it "sends the draft on cmd-enter", ->
      InboxTestUtils.keyPress("cmd-enter", @composer.getDOMNode())
      expect(@composer._sendDraft).toHaveBeenCalled()

    it "does not send the draft on enter if the button isn't in focus", ->
      InboxTestUtils.keyPress("enter", @composer.getDOMNode())
      expect(@composer._sendDraft).not.toHaveBeenCalled()

    it "sends the draft on enter when the button is in focus", ->
      sendBtn = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, "btn-send")
      InboxTestUtils.keyPress("enter", sendBtn.getDOMNode())
      expect(@composer._sendDraft).toHaveBeenCalled()

    it "shows and focuses on bcc field", ->

    it "shows and focuses on cc field", ->

    it "shows and focuses on bcc field when already open", ->

describe "When composing a new message", ->
  it "Can add someone in the to field", ->

  it "Can add someone in the cc field", ->

  it "Can add someone in the bcc field", ->

describe "When replying to a message", ->

describe "When replying all to a message", ->

describe "When forwarding a message", ->

describe "When changing the subject of a message", ->
