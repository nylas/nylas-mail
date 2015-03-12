_ = require "underscore-plus"
proxyquire = require "proxyquire"

React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

{Actions,
 Contact,
 Message,
 Namespace,
 DraftStore,
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

draftStoreProxyStub = (localId, returnedDraft) ->
  listen: -> ->
  draft: -> (returnedDraft ? new Message(draft: true))
  changes:
    add: ->
    commit: ->
    applyToModel: ->

searchContactStub = (email) ->
  _.filter(users, (u) u.email.toLowerCase() is email.toLowerCase())

ComposerView = proxyquire "../lib/composer-view.cjsx",
  "./file-uploads.cjsx": reactStub("file-uploads")
  "./participants-text-field.cjsx": textFieldStub("")
  "inbox-exports":
    ContactStore:
      searchContacts: (email) -> searchContactStub
    ComponentRegistry:
      listen: -> ->
      findViewByName: (component) -> reactStub(component)
      findAllViewsByRole: (role) -> [reactStub('a'),reactStub('b')]
    DraftStore: DraftStore

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
    it "shows and focuses on bcc field", ->

    it "shows and focuses on cc field", ->

    it "shows and focuses on bcc field when already open", ->

describe "populated composer", ->
  # This will setup the mocks necessary to make the composer element (once
  # mounted) think it's attached to the given draft. This mocks out the
  # proxy system used by the composer.
  DRAFT_LOCAL_ID = "local-123"
  useDraft = (draftAttributes={}) ->
    @draft = new Message _.extend({draft: true}, draftAttributes)
    spyOn(DraftStore, "sessionForLocalId").andCallFake (localId) =>
      return draftStoreProxyStub(localId, @draft)

  useFullDraft = ->
    useDraft.call @,
      from: [u1]
      to: [u2]
      cc: [u3, u4]
      bcc: [u5]
      subject: "Test Message 1"
      body: "Hello <b>World</b><br/> This is a test"

  makeComposer = ->
    @composer = ReactTestUtils.renderIntoDocument(
      <ComposerView localId={DRAFT_LOCAL_ID} />
    )

  describe "When displaying info from a draft", ->
    beforeEach ->
      useFullDraft.apply(@)
      makeComposer.call(@)

    it "attaches the draft to the proxy", ->
      expect(@draft).toBeDefined()
      expect(@composer._proxy.draft()).toBe @draft

    it "set the state based on the draft", ->
      expect(@composer.state.from).toBeUndefined()
      expect(@composer.state.to).toEqual [u2]
      expect(@composer.state.cc).toEqual [u3, u4]
      expect(@composer.state.bcc).toEqual [u5]
      expect(@composer.state.subject).toEqual "Test Message 1"
      expect(@composer.state.body).toEqual "Hello <b>World</b><br/> This is a test"

  describe "when deciding whether or not to show the subject", ->
    it "shows the subject when the subject is empty", ->
      useDraft.call @, subject: ""
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe true

    it "shows the subject when the subject looks like a fwd", ->
      useDraft.call @, subject: "Fwd: This is the message"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe true

    it "shows the subject when the subject looks like a fwd", ->
      useDraft.call @, subject: "fwd foo"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe true

    it "doesn't show subject when subject has fwd text in it", ->
      useDraft.call @, subject: "Trick fwd"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe false

    it "doesn't show the subject otherwise", ->
      useDraft.call @, subject: "Foo bar baz"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe false

  describe "when deciding whether or not to show cc and bcc", ->
    it "doesn't show cc when there's no one to cc", ->
      useDraft.call @, cc: []
      makeComposer.call @
      expect(@composer.state.showcc).toBe false

    it "shows cc when populated", ->
      useDraft.call @, cc: [u1,u2]
      makeComposer.call @
      expect(@composer.state.showcc).toBe true

    it "doesn't show bcc when there's no one to bcc", ->
      useDraft.call @, bcc: []
      makeComposer.call @
      expect(@composer.state.showbcc).toBe false

    it "shows bcc when populated", ->
      useDraft.call @, bcc: [u2,u3]
      makeComposer.call @
      expect(@composer.state.showbcc).toBe true

  describe "When sending a message", ->
    beforeEach ->
      remote = require('remote')
      @dialog = remote.require('dialog')
      spyOn(remote, "getCurrentWindow")
      spyOn(@dialog, "showMessageBox")
      spyOn(Actions, "sendDraft")
      DraftStore._sendingState = {}

    it "shows a warning if there are no recipients", ->
      useDraft.call @, subject: "no recipients"
      makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).not.toHaveBeenCalled()
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.buttons).toEqual ['Edit Message']

    it "shows a warning if there's no subject", ->
      useDraft.call @, to: [u1], subject: ""
      makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).not.toHaveBeenCalled()
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.buttons).toEqual ['Cancel', 'Send Anyway']

    it "doesn't show a warning if requirements are satisfied", ->
      useFullDraft.apply(@); makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).toHaveBeenCalled()
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    describe "Checking for attachments", ->
      warn = (body) ->
        useDraft.call @, subject: "Subject", to: [u1], body: body
        makeComposer.call(@); @composer._sendDraft()
        expect(Actions.sendDraft).not.toHaveBeenCalled()
        expect(@dialog.showMessageBox).toHaveBeenCalled()
        dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
        expect(dialogArgs.buttons).toEqual ['Cancel', 'Send Anyway']

      noWarn = (body) ->
        useDraft.call @, subject: "Subject", to: [u1], body: "Sup yo"
        makeComposer.call(@); @composer._sendDraft()
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(@dialog.showMessageBox).not.toHaveBeenCalled()

      it "warns", -> warn.call(@, "Check out the attached file")
      it "warns", -> warn.call(@, "I've added an attachment")
      it "warns", -> warn.call(@, "I'm going to attach the file")

      it "doesn't warn", -> noWarn.call(@, "sup yo")
      it "doesn't warn", -> noWarn.call(@, "Look at the file")

    it "doesn't show a warning if you've attached a file", ->
      useDraft.call @,
        subject: "Subject"
        to: [u1]
        body: "Check out attached file"
        files: [{filename:"abc"}]
      makeComposer.call(@); @composer._sendDraft()
      expect(Actions.sendDraft).toHaveBeenCalled()
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "bypasses the warning if force bit is set", ->
      useDraft.call @, to: [u1], subject: ""
      makeComposer.call(@)
      @composer._sendDraft(force: true)
      expect(Actions.sendDraft).toHaveBeenCalled()
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "sends when you click the send button", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendButton.getDOMNode()
      ReactTestUtils.Simulate.click sendBtn
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_LOCAL_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    simulateDraftStore = ->
      DraftStore._sendingState[DRAFT_LOCAL_ID] = true
      DraftStore.trigger()

    it "doesn't send twice if you double click", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendButton.getDOMNode()
      ReactTestUtils.Simulate.click sendBtn
      simulateDraftStore()
      ReactTestUtils.Simulate.click sendBtn
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_LOCAL_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    it "disables the composer once sending has started", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendButton.getDOMNode()
      cover = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, "composer-cover")
      expect(cover.getDOMNode().style.display).toBe "none"
      ReactTestUtils.Simulate.click sendBtn
      simulateDraftStore()
      expect(cover.getDOMNode().style.display).toBe "block"
      expect(@composer.state.isSending).toBe true

    it "re-enables the composer if sending threw an error", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendButton.getDOMNode()
      ReactTestUtils.Simulate.click sendBtn
      simulateDraftStore()
      expect(@composer.state.isSending).toBe true
      Actions.sendDraftError("oh no")
      DraftStore._sendingState[DRAFT_LOCAL_ID] = false
      DraftStore.trigger()
      expect(@composer.state.isSending).toBe false

    describe "when sending a message with keyboard inputs", ->
      beforeEach ->
        useFullDraft.apply(@)
        makeComposer.call(@)
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

      it "doesn't let you send twice", ->
        sendBtn = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, "btn-send")
        InboxTestUtils.keyPress("enter", sendBtn.getDOMNode())
        expect(@composer._sendDraft).toHaveBeenCalled()


  describe "When composing a new message", ->
    it "Can add someone in the to field", ->

    it "Can add someone in the cc field", ->

    it "Can add someone in the bcc field", ->

  describe "When replying to a message", ->

  describe "When replying all to a message", ->

  describe "When forwarding a message", ->

  describe "When changing the subject of a message", ->
