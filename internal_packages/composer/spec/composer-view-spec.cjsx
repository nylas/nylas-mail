_ = require "underscore"
proxyquire = require "proxyquire"

React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

{Actions,
 File,
 Contact,
 Message,
 Account,
 DraftStore,
 DatabaseStore,
 NylasTestUtils,
 AccountStore,
 FileUploadStore,
 ContactStore,
 ComponentRegistry} = require "nylas-exports"

{InjectedComponent} = require 'nylas-component-kit'

ParticipantsTextField = require '../lib/participants-text-field'

u1 = new Contact(name: "Christine Spang", email: "spang@nylas.com")
u2 = new Contact(name: "Michael Grinich", email: "mg@nylas.com")
u3 = new Contact(name: "Evan Morikawa",   email: "evan@nylas.com")
u4 = new Contact(name: "Zoë Leiper",      email: "zip@nylas.com")
u5 = new Contact(name: "Ben Gotow",       email: "ben@nylas.com")

file = new File(id: 'file_1_id', filename: 'a.png', contentType: 'image/png', size: 10, object: "file")

users = [u1, u2, u3, u4, u5]

reactStub = (className) ->
  React.createClass({render: -> <div className={className}>{@props.children}</div>})

textFieldStub = (className) ->
  React.createClass
    render: -> <div className={className}>{@props.children}</div>
    focus: ->

passThroughStub = (props={}) ->
  React.createClass
    render: -> <div {...props}>{props.children}</div>

draftStoreProxyStub = (draftClientId, returnedDraft) ->
  listen: -> ->
  draft: -> (returnedDraft ? new Message(draft: true))
  draftPristineBody: -> null
  draftClientId: draftClientId
  cleanup: ->
  changes:
    add: ->
    commit: -> Promise.resolve()
    applyToModel: ->

searchContactStub = (email) ->
  _.filter(users, (u) u.email.toLowerCase() is email.toLowerCase())

isValidContactStub = (contact) ->
  contact.email.indexOf('@') > 0

ComposerView = proxyquire "../lib/composer-view",
  "./file-upload": reactStub("file-upload")
  "./image-file-upload": reactStub("image-file-upload")
  "nylas-exports":
    ContactStore:
      searchContacts: searchContactStub
      isValidContact: isValidContactStub
    DraftStore: DraftStore

beforeEach ->
  # The AccountStore isn't set yet in the new window, populate it first.
  AccountStore.populateItems().then ->
    draft = new Message
      from: [AccountStore.current().me()]
      date: (new Date)
      draft: true
      accountId: AccountStore.current().id

    DatabaseStore.persistModel(draft).then ->
      return draft

describe "A blank composer view", ->
  beforeEach ->
    @composer = ReactTestUtils.renderIntoDocument(
      <ComposerView draftClientId="test123" />
    )
    @composer.setState
      body: ""

  it 'should render into the document', ->
    expect(ReactTestUtils.isCompositeComponentWithType @composer, ComposerView).toBe true

  describe "testing keyboard inputs", ->
    it "shows and focuses on bcc field", ->

    it "shows and focuses on cc field", ->

    it "shows and focuses on bcc field when already open", ->

# This will setup the mocks necessary to make the composer element (once
# mounted) think it's attached to the given draft. This mocks out the
# proxy system used by the composer.
DRAFT_CLIENT_ID = "local-123"
useDraft = (draftAttributes={}) ->
  @draft = new Message _.extend({draft: true, body: ""}, draftAttributes)
  draft = @draft
  proxy = draftStoreProxyStub(DRAFT_CLIENT_ID, @draft)
  @proxy = proxy


  spyOn(ComposerView.prototype, "componentWillMount").andCallFake ->
    # NOTE: This is called in the context of the component.
    @_prepareForDraft(DRAFT_CLIENT_ID)
    @_setupSession(proxy)

  # Normally when sessionForClientId resolves, it will call `_setupSession`
  # and pass the new session proxy. However, in our faked
  # `componentWillMount`, we manually call sessionForClientId to make this
  # part of the test synchronous. We need to make the `then` block of the
  # sessionForClientId do nothing so `_setupSession` is not called twice!
  spyOn(DraftStore, "sessionForClientId").andCallFake -> then: ->

useFullDraft = ->
  useDraft.call @,
    from: [u1]
    to: [u2]
    cc: [u3, u4]
    bcc: [u5]
    subject: "Test Message 1"
    body: "Hello <b>World</b><br/> This is a test"
    replyToMessageId: null

makeComposer = ->
  @composer = ReactTestUtils.renderIntoDocument(
    <ComposerView draftClientId={DRAFT_CLIENT_ID} />
  )

describe "populated composer", ->
  beforeEach ->
    @isSending = {state: false}
    spyOn(DraftStore, "isSendingDraft").andCallFake => @isSending.state

  describe "when sending a new message", ->
    it 'makes a request with the message contents', ->
      useDraft.call @
      makeComposer.call @
      editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@composer, 'contentEditable'))
      spyOn(@proxy.changes, "add")
      editableNode.innerHTML = "Hello <strong>world</strong>"
      ReactTestUtils.Simulate.input(editableNode)
      expect(@proxy.changes.add).toHaveBeenCalled()
      expect(@proxy.changes.add.calls.length).toBe 1
      body = @proxy.changes.add.calls[0].args[0].body
      expect(body).toBe "<head></head><body>Hello <strong>world</strong></body>"

  describe "when sending a reply-to message", ->
    beforeEach ->
      @replyBody = """<blockquote class="gmail_quote">On Sep 3 2015, at 12:14 pm, Evan Morikawa &lt;evan@evanmorikawa.com&gt; wrote:<br>This is a test!</blockquote>"""

      useDraft.call @,
        from: [u1]
        to: [u2]
        subject: "Test Reply Message 1"
        body: @replyBody

      makeComposer.call @
      @editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@composer, 'contentEditable'))
      spyOn(@proxy.changes, "add")

    it 'begins with the replying message collapsed', ->
      expect(@editableNode.innerHTML).toBe ""

    it 'saves the full new body, plus quoted text', ->
      @editableNode.innerHTML = "Hello <strong>world</strong>"
      ReactTestUtils.Simulate.input(@editableNode)
      expect(@proxy.changes.add).toHaveBeenCalled()
      expect(@proxy.changes.add.calls.length).toBe 1
      body = @proxy.changes.add.calls[0].args[0].body
      expect(body).toBe """<head></head><body>Hello <strong>world</strong>#{@replyBody}</body>"""

  describe "when sending a forwarded message message", ->
    beforeEach ->
      @fwdBody = """<br><br><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
      Begin forwarded message:
      <br><br>
      From: Evan Morikawa &lt;evan@evanmorikawa.com&gt;<br>Subject: Test Forward Message 1<br>Date: Sep 3 2015, at 12:14 pm<br>To: Evan Morikawa &lt;evan@nylas.com&gt;
      <br><br>

    <meta content="text/html; charset=us-ascii">This is a test!
    </blockquote>"""

      useDraft.call @,
        from: [u1]
        to: [u2]
        subject: "Fwd: Test Forward Message 1"
        body: @fwdBody

      makeComposer.call @
      @editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@composer, 'contentEditable'))
      spyOn(@proxy.changes, "add")

    it 'begins with the forwarded message expanded', ->
      expect(@editableNode.innerHTML).toBe @fwdBody

    it 'saves the full new body, plus forwarded text', ->
      @editableNode.innerHTML = "Hello <strong>world</strong>#{@fwdBody}"
      ReactTestUtils.Simulate.input(@editableNode)
      expect(@proxy.changes.add).toHaveBeenCalled()
      expect(@proxy.changes.add.calls.length).toBe 1
      body = @proxy.changes.add.calls[0].args[0].body
      expect(body).toBe """Hello <strong>world</strong>#{@fwdBody}"""

  describe "When displaying info from a draft", ->
    beforeEach ->
      useFullDraft.apply(@)
      makeComposer.call(@)

    it "attaches the draft to the proxy", ->
      expect(@draft).toBeDefined()
      expect(@composer._proxy.draft()).toBe @draft

    it "set the state based on the draft", ->
      expect(@composer.state.from).toEqual [u1]
      expect(@composer.state.showfrom).toEqual true
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

    it "doesn't show subject when replyToMessageId exists", ->
      useDraft.call @, subject: "should hide", replyToMessageId: "some-id"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe false

    it "shows the subject otherwise", ->
      useDraft.call @, subject: "Foo bar baz"
      makeComposer.call @
      expect(@composer._shouldShowSubject()).toBe true

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

  describe "when focus() is called", ->
    describe "if a field name is provided", ->
      it "should focus that field", ->
        useDraft.call(@, cc: [u2])
        makeComposer.call(@)
        spyOn(@composer.refs['textFieldCc'], 'focus')
        @composer.focus('textFieldCc')
        advanceClock(1000)
        expect(@composer.refs['textFieldCc'].focus).toHaveBeenCalled()

    describe "if the draft is a forward", ->
      it "should focus the to field", ->
        useDraft.call(@, {subject: 'Fwd: This is a test'})
        makeComposer.call(@)
        spyOn(@composer.refs['textFieldTo'], 'focus')
        @composer.focus()
        advanceClock(1000)
        expect(@composer.refs['textFieldTo'].focus).toHaveBeenCalled()

    describe "if the draft is a normal message", ->
      it "should focus on the body", ->
        useDraft.call(@)
        makeComposer.call(@)
        spyOn(@composer.refs['contentBody'], 'focus')
        @composer.focus()
        advanceClock(1000)
        expect(@composer.refs['contentBody'].focus).toHaveBeenCalled()

    describe "if the draft has not yet loaded", ->
      it "should set _focusOnUpdate and focus after the next render", ->
        @draft = new Message(draft: true, body: "")
        proxy = draftStoreProxyStub(DRAFT_CLIENT_ID, @draft)
        proxyResolve = null
        spyOn(DraftStore, "sessionForClientId").andCallFake ->
          new Promise (resolve, reject) ->
            proxyResolve = resolve

        makeComposer.call(@)

        spyOn(@composer.refs['contentBody'], 'focus')
        @composer.focus()
        advanceClock(1000)
        expect(@composer.refs['contentBody'].focus).not.toHaveBeenCalled()

        proxyResolve(proxy)

        advanceClock(1000)
        expect(@composer.refs['contentBody'].focus).toHaveBeenCalled()

  describe "when emptying cc/bcc fields", ->

    it "focuses on to when bcc is emptied and there's no cc field", ->
      useDraft.call(@, bcc: [u1])
      makeComposer.call(@)
      spyOn(@composer.refs['textFieldTo'], 'focus')
      spyOn(@composer.refs['textFieldBcc'], 'focus')

      bcc = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@composer, ParticipantsTextField, field: "bcc")[0]
      @draft.bcc = []
      bcc.props.onEmptied()

      expect(@composer.state.showbcc).toBe false
      advanceClock(1000)
      expect(@composer.refs['textFieldTo'].focus).toHaveBeenCalled()
      expect(@composer.refs['textFieldCc']).not.toBeDefined()
      expect(@composer.refs['textFieldBcc']).not.toBeDefined()

    it "focuses on cc when bcc is emptied and cc field is available", ->
      useDraft.call(@, cc: [u2], bcc: [u1])
      makeComposer.call(@)
      spyOn(@composer.refs['textFieldTo'], 'focus')
      spyOn(@composer.refs['textFieldCc'], 'focus')
      spyOn(@composer.refs['textFieldBcc'], 'focus')

      bcc = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@composer, ParticipantsTextField, field: "bcc")[0]
      @draft.bcc = []
      bcc.props.onEmptied()
      expect(@composer.state.showbcc).toBe false
      advanceClock(1000)
      expect(@composer.refs['textFieldTo'].focus).not.toHaveBeenCalled()
      expect(@composer.refs['textFieldCc'].focus).toHaveBeenCalled()
      expect(@composer.refs['textFieldBcc']).not.toBeDefined()

    it "focuses on to when cc is emptied", ->
      useDraft.call(@, cc: [u1], bcc: [u2])
      makeComposer.call(@)
      spyOn(@composer.refs['textFieldTo'], 'focus')
      spyOn(@composer.refs['textFieldCc'], 'focus')
      spyOn(@composer.refs['textFieldBcc'], 'focus')

      cc = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@composer, ParticipantsTextField, field: "cc")[0]
      @draft.cc = []
      cc.props.onEmptied()
      expect(@composer.state.showcc).toBe false
      advanceClock(1000)
      expect(@composer.refs['textFieldTo'].focus).toHaveBeenCalled()
      expect(@composer.refs['textFieldCc']).not.toBeDefined()
      expect(@composer.refs['textFieldBcc'].focus).not.toHaveBeenCalled()

  describe "when participants are added during a draft update", ->
    it "shows the cc fields and bcc fields to ensure participants are never hidden", ->
      useDraft.call(@, cc: [], bcc: [])
      makeComposer.call(@)
      expect(@composer.state.showbcc).toBe(false)
      expect(@composer.state.showcc).toBe(false)

      # Simulate a change event fired by the DraftStoreProxy
      @draft.cc = [u1]
      @composer._onDraftChanged()

      expect(@composer.state.showbcc).toBe(false)
      expect(@composer.state.showcc).toBe(true)

      # Simulate a change event fired by the DraftStoreProxy
      @draft.bcc = [u2]
      @composer._onDraftChanged()
      expect(@composer.state.showbcc).toBe(true)
      expect(@composer.state.showcc).toBe(true)

  describe "When sending a message", ->
    beforeEach ->
      spyOn(atom, "isMainWindow").andReturn true
      remote = require('remote')
      @dialog = remote.require('dialog')
      spyOn(remote, "getCurrentWindow")
      spyOn(@dialog, "showMessageBox")
      spyOn(Actions, "sendDraft")

    it "shows an error if there are no recipients", ->
      useDraft.call @, subject: "no recipients"
      makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).not.toHaveBeenCalled()
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.detail).toEqual("You need to provide one or more recipients before sending the message.")
      expect(dialogArgs.buttons).toEqual ['Edit Message']

    it "shows an error if a recipient is invalid", ->
      useDraft.call @,
        subject: 'hello world!'
        to: [new Contact(email: 'lol', name: 'lol')]
      makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).not.toHaveBeenCalled()
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.detail).toEqual("lol is not a valid email address - please remove or edit it before sending.")
      expect(dialogArgs.buttons).toEqual ['Edit Message']

    describe "empty body warning", ->
      it "warns if the body of the email is still the pristine body", ->
        pristineBody = "<head></head><body><br><br></body>"

        useDraft.call @,
          to: [u1]
          subject: "Hello World"
          body: pristineBody
        makeComposer.call(@)

        spyOn(@composer._proxy, 'draftPristineBody').andCallFake -> pristineBody

        @composer._sendDraft()
        expect(Actions.sendDraft).not.toHaveBeenCalled()
        expect(@dialog.showMessageBox).toHaveBeenCalled()
        dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
        expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

      it "does not warn if the body of the email is all quoted text, but the email is a forward", ->
        useDraft.call @,
          to: [u1]
          subject: "Fwd: Hello World"
          body: "<br><br><blockquote class='gmail_quote'>This is my quoted text!</blockquote>"
        makeComposer.call(@)
        @composer._sendDraft()
        expect(Actions.sendDraft).toHaveBeenCalled()

      it "does not warn if the user has attached a file", ->
        useDraft.call @,
          to: [u1]
          subject: "Hello World"
          body: ""
          files: [file]
        makeComposer.call(@)
        @composer._sendDraft()
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "shows a warning if there's no subject", ->
      useDraft.call @, to: [u1], subject: ""
      makeComposer.call(@)
      @composer._sendDraft()
      expect(Actions.sendDraft).not.toHaveBeenCalled()
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

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
        expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

      noWarn = (body) ->
        useDraft.call @, subject: "Subject", to: [u1], body: body
        makeComposer.call(@); @composer._sendDraft()
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(@dialog.showMessageBox).not.toHaveBeenCalled()

      it "warns", -> warn.call(@, "Check out the attached file")
      it "warns", -> warn.call(@, "I've added an attachment")
      it "warns", -> warn.call(@, "I'm going to attach the file")
      it "warns", -> warn.call(@, "Hey attach me <blockquote class='gmail_quote'>sup</blockquote>")

      it "doesn't warn", -> noWarn.call(@, "sup yo")
      it "doesn't warn", -> noWarn.call(@, "Look at the file")
      it "doesn't warn", -> noWarn.call(@, "Hey there <blockquote class='gmail_quote'>attach</blockquote>")

    it "doesn't show a warning if you've attached a file", ->
      useDraft.call @,
        subject: "Subject"
        to: [u1]
        body: "Check out attached file"
        files: [file]
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
      sendBtn = React.findDOMNode(@composer.refs.sendButton)
      ReactTestUtils.Simulate.click sendBtn
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_CLIENT_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    it "doesn't send twice if you double click", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = React.findDOMNode(@composer.refs.sendButton)
      ReactTestUtils.Simulate.click sendBtn
      @isSending.state = true
      DraftStore.trigger()
      ReactTestUtils.Simulate.click sendBtn
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_CLIENT_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    describe "when sending a message with keyboard inputs", ->
      beforeEach ->
        useFullDraft.apply(@)
        makeComposer.call(@)
        spyOn(@composer, "_sendDraft")
        NylasTestUtils.loadKeymap("internal_packages/composer/keymaps/composer")

      it "sends the draft on cmd-enter", ->
        NylasTestUtils.keyPress("cmd-enter", React.findDOMNode(@composer))
        expect(@composer._sendDraft).toHaveBeenCalled()

      it "does not send the draft on enter if the button isn't in focus", ->
        NylasTestUtils.keyPress("enter", React.findDOMNode(@composer))
        expect(@composer._sendDraft).not.toHaveBeenCalled()

      it "sends the draft on enter when the button is in focus", ->
        sendBtn = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, "btn-send")
        NylasTestUtils.keyPress("enter", React.findDOMNode(sendBtn))
        expect(@composer._sendDraft).toHaveBeenCalled()

      it "doesn't let you send twice", ->
        sendBtn = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, "btn-send")
        NylasTestUtils.keyPress("enter", React.findDOMNode(sendBtn))
        expect(@composer._sendDraft).toHaveBeenCalled()

  describe "drag and drop", ->
    beforeEach ->
      useDraft.call @,
        to: [u1]
        subject: "Hello World"
        body: ""
        files: [file]
      makeComposer.call(@)

    describe "_shouldAcceptDrop", ->
      it "should return true if the event is carrying native files", ->
        event =
          dataTransfer:
            files:[{'pretend':'imafile'}]
            types:[]
        expect(@composer._shouldAcceptDrop(event)).toBe(true)

      it "should return true if the event is carrying a non-native file URL not on the draft", ->
        event =
          dataTransfer:
            files:[]
            types:['text/uri-list']
        spyOn(@composer, '_nonNativeFilePathForDrop').andReturn("file://one-file")
        spyOn(FileUploadStore, 'linkedUpload').andReturn({filePath: "file://other-file"})

        expect(@composer.state.files.length).toBe(1)
        expect(@composer._shouldAcceptDrop(event)).toBe(true)

      it "should return false if the event is carrying a non-native file URL already on the draft", ->
        event =
          dataTransfer:
            files:[]
            types:['text/uri-list']
        spyOn(@composer, '_nonNativeFilePathForDrop').andReturn("file://one-file")
        spyOn(FileUploadStore, 'linkedUpload').andReturn({filePath: "file://one-file"})

        expect(@composer.state.files.length).toBe(1)
        expect(@composer._shouldAcceptDrop(event)).toBe(false)

      it "should return false otherwise", ->
        event =
          dataTransfer:
            files:[]
            types:['text/plain']
        expect(@composer._shouldAcceptDrop(event)).toBe(false)

    describe "_nonNativeFilePathForDrop", ->
      it "should return a path in the text/nylas-file-url data", ->
        event =
          dataTransfer:
            types: ['text/nylas-file-url']
            getData: -> "image/png:test.png:file:///Users/bengotow/Desktop/test.png"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe("/Users/bengotow/Desktop/test.png")

      it "should return a path in the text/uri-list data", ->
        event =
          dataTransfer:
            types: ['text/uri-list']
            getData: -> "file:///Users/bengotow/Desktop/test.png"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe("/Users/bengotow/Desktop/test.png")

      it "should return null otherwise", ->
        event =
          dataTransfer:
            types: ['text/plain']
            getData: -> "Hello world"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe(null)

      it "should urldecode the contents of the text/uri-list field", ->
        event =
          dataTransfer:
            types: ['text/uri-list']
            getData: -> "file:///Users/bengotow/Desktop/Screen%20shot.png"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe("/Users/bengotow/Desktop/Screen shot.png")

      it "should return null if text/uri-list contains a non-file path", ->
        event =
          dataTransfer:
            types: ['text/uri-list']
            getData: -> "http://apple.com"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe(null)

      it "should return null if text/nylas-file-url contains a non-file path", ->
        event =
          dataTransfer:
            types: ['text/nylas-file-url']
            getData: -> "application/json:filename.json:undefined"
        expect(@composer._nonNativeFilePathForDrop(event)).toBe(null)

  describe "when scrolling to track your cursor", ->
    it "it tracks when you're at the end of the text", ->

    it "it doesn't track when typing in the middle of the body", ->

    it "it doesn't track when typing in the middle of the body", ->

  describe "When composing a new message", ->
    it "Can add someone in the to field", ->

    it "Can add someone in the cc field", ->

    it "Can add someone in the bcc field", ->

  describe "When replying to a message", ->

  describe "When replying all to a message", ->

  describe "When forwarding a message", ->

  describe "When changing the subject of a message", ->

  describe "A draft with files (attachments) and uploads", ->
    beforeEach ->
      @file1 = new File
        id: "f_1"
        filename: "f1.pdf"
        size: 1230

      @file2 = new File
        id: "f_2"
        filename: "f2.jpg"
        size: 4560

      @file3 = new File
        id: "f_3"
        filename: "f3.png"
        size: 7890

      @up1 =
        uploadTaskId: 4
        messageClientId: DRAFT_CLIENT_ID
        filePath: "/foo/bar/f4.bmp"
        fileName: "f4.bmp"
        fileSize: 1024

      @up2 =
        uploadTaskId: 5
        messageClientId: DRAFT_CLIENT_ID
        filePath: "/foo/bar/f5.zip"
        fileName: "f5.zip"
        fileSize: 1024

      spyOn(Actions, "fetchFile")
      spyOn(FileUploadStore, "linkedUpload").andReturn null
      spyOn(FileUploadStore, "uploadsForMessage").andReturn [@up1, @up2]

      useDraft.call @, files: [@file1, @file2]
      makeComposer.call @

    it 'starts fetching attached files', ->
      waitsFor ->
        Actions.fetchFile.callCount == 1
      runs ->
        expect(Actions.fetchFile).toHaveBeenCalled()
        expect(Actions.fetchFile.calls.length).toBe(1)
        expect(Actions.fetchFile.calls[0].args[0]).toBe @file2

    it 'injects an Attachment component for non image files', ->
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@composer, InjectedComponent, matching: {role: "Attachment"})
      expect(els.length).toBe 1

    it 'injects an Attachment:Image component for image files', ->
      els = ReactTestUtils.scryRenderedComponentsWithTypeAndProps(@composer, InjectedComponent, matching: {role: "Attachment:Image"})
      expect(els.length).toBe 1

describe "when the DraftStore `isSending` isn't stubbed out", ->
  beforeEach ->
    DraftStore._draftsSending = {}

  it "doesn't send twice in a popout", ->
    spyOn(Actions, "queueTask")
    spyOn(Actions, "sendDraft").andCallThrough()
    useFullDraft.call(@)
    makeComposer.call(@)
    @composer._sendDraft()
    @composer._sendDraft()
    expect(Actions.sendDraft.calls.length).toBe 1

  it "doesn't send twice in the main window", ->
    spyOn(Actions, "queueTask")
    spyOn(Actions, "sendDraft").andCallThrough()
    spyOn(atom, "isMainWindow").andReturn true
    useFullDraft.call(@)
    makeComposer.call(@)
    @composer._sendDraft()
    @composer._sendDraft()
    expect(Actions.sendDraft.calls.length).toBe 1
