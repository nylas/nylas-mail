_ = require "underscore"
proxyquire = require "proxyquire"

React = require "react"
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

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
 FocusedContentStore,
 ComponentRegistry} = require "nylas-exports"

{InjectedComponent, ParticipantsTextField} = require 'nylas-component-kit'

DraftEditingSession = require '../../../src/flux/stores/draft-editing-session'
ComposerEditor = require('../lib/composer-editor').default
Fields = require('../lib/fields').default

u1 = new Contact(name: "Christine Spang", email: "spang@nylas.com")
u2 = new Contact(name: "Michael Grinich", email: "mg@nylas.com")
u3 = new Contact(name: "Evan Morikawa",   email: "evan@nylas.com")
u4 = new Contact(name: "Zoë Leiper",      email: "zip@nylas.com")
u5 = new Contact(name: "Ben Gotow",       email: "ben@nylas.com")

f1 = new File(id: 'file_1_id', filename: 'a.png', contentType: 'image/png', size: 10, object: "file")
f2 = new File(id: 'file_2_id', filename: 'b.pdf', contentType: '', size: 999999, object: "file")

users = [u1, u2, u3, u4, u5]

ComposerView = require("../lib/composer-view").default

# This will setup the mocks necessary to make the composer element (once
# mounted) think it's attached to the given draft. This mocks out the
# proxy system used by the composer.
DRAFT_CLIENT_ID = "local-123"

useDraft = (draftAttributes={}) ->
  @draft = new Message _.extend({draft: true, body: ""}, draftAttributes)
  @draft.clientId = DRAFT_CLIENT_ID
  @session = new DraftEditingSession(DRAFT_CLIENT_ID, @draft)
  DraftStore._draftSessions[DRAFT_CLIENT_ID] = @session

useFullDraft = ->
  useDraft.call @,
    from: [AccountStore.accounts()[0].me()]
    to: [u2]
    cc: [u3, u4]
    bcc: [u5]
    files: [f1, f2]
    subject: "Test Message 1"
    body: "Hello <b>World</b><br/> This is a test"
    replyToMessageId: null

makeComposer = (props={}) ->
  @composer = NylasTestUtils.renderIntoDocument(
    <ComposerView draft={@draft} session={@session} {...props} />
  )
  advanceClock()

describe "ComposerView", ->
  beforeEach ->
    ComposerEditor.containerRequired = false
    ComponentRegistry.register(ComposerEditor, role: "Composer:Editor")

    @isSending = false
    spyOn(DraftStore, "isSendingDraft").andCallFake => @isSending
    spyOn(DraftEditingSession.prototype, 'changeSetCommit').andCallFake (draft) =>
      @draft = draft
    spyOn(ContactStore, "searchContacts").andCallFake (email) =>
      return _.filter(users, (u) u.email.toLowerCase() is email.toLowerCase())
    spyOn(Contact.prototype, "isValid").andCallFake (contact) ->
      return @email.indexOf('@') > 0

  afterEach ->
    ComposerEditor.containerRequired = undefined
    ComponentRegistry.unregister(ComposerEditor)
    DraftStore._cleanupAllSessions()
    NylasTestUtils.removeFromDocument(@composer)

  describe "when sending a new message", ->
    it 'makes a request with the message contents', ->
      useDraft.call(@)
      makeComposer.call(@)
      editableNode = ReactDOM.findDOMNode(@composer).querySelector('[contenteditable]')
      spyOn(@session.changes, "add")
      editableNode.innerHTML = "Hello <strong>world</strong>"
      @composer.refs[Fields.Body]._onDOMMutated(["mutated"])
      expect(@session.changes.add).toHaveBeenCalled()
      expect(@session.changes.add.calls.length).toBe 1
      body = @session.changes.add.calls[0].args[0].body
      expect(body).toBe "Hello <strong>world</strong>"

  describe "when sending a reply-to message", ->
    beforeEach ->
      useDraft.call @,
        from: [u1]
        to: [u2]
        subject: "Test Reply Message 1"
        body: ""
        replyToMessageId: "1"

      makeComposer.call @
      @editableNode = ReactDOM.findDOMNode(@composer).querySelector('[contenteditable]')
      spyOn(@session.changes, "add")

    it 'begins with empty body', ->
      expect(@editableNode.innerHTML).toBe ""

  describe "when sending a forwarded message", ->
    beforeEach ->
      @fwdBody = """<br><br><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex;">
      ---------- Forwarded message ---------
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
      @editableNode = ReactDOM.findDOMNode(@composer).querySelector('[contenteditable]')
      spyOn(@session.changes, "add")

    it 'begins with the forwarded message expanded', ->
      expect(@editableNode.innerHTML).toBe @fwdBody

    it 'saves the full new body, plus forwarded text', ->
      @editableNode.innerHTML = "Hello <strong>world</strong>#{@fwdBody}"
      @composer.refs[Fields.Body]._onDOMMutated(["mutated"])
      expect(@session.changes.add).toHaveBeenCalled()
      expect(@session.changes.add.calls.length).toBe 1
      body = @session.changes.add.calls[0].args[0].body
      expect(body).toBe """Hello <strong>world</strong>#{@fwdBody}"""

  describe "When sending a message", ->
    beforeEach ->
      spyOn(NylasEnv, "isMainWindow").andReturn true
      {remote} = require('electron')
      @dialog = remote.dialog
      spyOn(remote, "getCurrentWindow")
      spyOn(@dialog, "showMessageBox")
      spyOn(Actions, "sendDraft")

    it "shows an error if there are no recipients", ->
      useDraft.call @, subject: "no recipients"
      makeComposer.call(@)
      status = @composer._isValidDraft()
      expect(status).toBe false
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.detail).toEqual("You need to provide one or more recipients before sending the message.")
      expect(dialogArgs.buttons).toEqual ['Edit Message', 'Cancel']

    it "shows an error if a recipient is invalid", ->
      useDraft.call @,
        subject: 'hello world!'
        to: [new Contact(email: 'lol', name: 'lol')]
      makeComposer.call(@)
      status = @composer._isValidDraft()
      expect(status).toBe false
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.detail).toEqual("lol is not a valid email address - please remove or edit it before sending.")
      expect(dialogArgs.buttons).toEqual ['Edit Message', 'Cancel']

    describe "empty body warning", ->
      it "warns if the body of the email is still the pristine body", ->
        pristineBody = "<br><br>"

        useDraft.call @,
          to: [u1]
          subject: "Hello World"
          body: pristineBody
        makeComposer.call(@)

        spyOn(@session, 'draftPristineBody').andCallFake -> pristineBody

        status = @composer._isValidDraft()
        expect(status).toBe false
        expect(@dialog.showMessageBox).toHaveBeenCalled()
        dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
        expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

      it "does not warn if the body of the email is all quoted text, but the email is a forward", ->
        useDraft.call @,
          to: [u1]
          subject: "Fwd: Hello World"
          body: "<br><br><blockquote class='gmail_quote'>This is my quoted text!</blockquote>"
        makeComposer.call(@)
        status = @composer._isValidDraft()
        expect(status).toBe true

      it "does not warn if the user has attached a file", ->
        useDraft.call @,
          to: [u1]
          subject: "Hello World"
          body: ""
          files: [f1]
        makeComposer.call(@)
        status = @composer._isValidDraft()
        expect(status).toBe true
        expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "shows a warning if there's no subject", ->
      useDraft.call @, to: [u1], subject: ""
      makeComposer.call(@)
      status = @composer._isValidDraft()
      expect(status).toBe false
      expect(@dialog.showMessageBox).toHaveBeenCalled()
      dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
      expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

    it "doesn't show a warning if requirements are satisfied", ->
      useFullDraft.apply(@); makeComposer.call(@)
      status = @composer._isValidDraft()
      expect(status).toBe true
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    describe "Checking for attachments", ->
      warn = (body) ->
        useDraft.call @, subject: "Subject", to: [u1], body: body
        makeComposer.call(@)
        status = @composer._isValidDraft()
        expect(status).toBe false
        expect(@dialog.showMessageBox).toHaveBeenCalled()
        dialogArgs = @dialog.showMessageBox.mostRecentCall.args[1]
        expect(dialogArgs.buttons).toEqual ['Send Anyway', 'Cancel']

      noWarn = (body) ->
        useDraft.call @, subject: "Subject", to: [u1], body: body
        makeComposer.call(@)
        status = @composer._isValidDraft()
        expect(status).toBe true
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
        files: [f1]
      makeComposer.call(@)
      status = @composer._isValidDraft()
      expect(status).toBe true
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "bypasses the warning if force bit is set", ->
      useDraft.call @, to: [u1], subject: ""
      makeComposer.call(@)
      status = @composer._isValidDraft(force: true)
      expect(status).toBe true
      expect(@dialog.showMessageBox).not.toHaveBeenCalled()

    it "sends when you click the send button", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendActionButton
      sendBtn.primaryClick()
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_CLIENT_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    it "doesn't send twice if you double click", ->
      useFullDraft.apply(@); makeComposer.call(@)
      sendBtn = @composer.refs.sendActionButton
      sendBtn.primaryClick()
      @isSending = true
      DraftStore.trigger()
      sendBtn.primaryClick()
      expect(Actions.sendDraft).toHaveBeenCalledWith(DRAFT_CLIENT_ID)
      expect(Actions.sendDraft.calls.length).toBe 1

    describe "when sending a message with keyboard inputs", ->
      beforeEach ->
        useFullDraft.apply(@)
        makeComposer.call(@)
        @$composer = @composer.refs.composerWrap

      it "sends the draft on cmd-enter", ->
        if process.platform is "darwin"
          mod = 'command'
        else
          mod = 'ctrl'

        ReactDOM.findDOMNode(@$composer).dispatchEvent(new CustomEvent('composer:send-message'))
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(Actions.sendDraft.calls.length).toBe 1

      it "doesn't let you send twice", ->
        ReactDOM.findDOMNode(@$composer).dispatchEvent(new CustomEvent('composer:send-message'))
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(Actions.sendDraft.calls.length).toBe 1
        @isSending = true
        DraftStore.trigger()
        ReactDOM.findDOMNode(@$composer).dispatchEvent(new CustomEvent('composer:send-message'))
        expect(Actions.sendDraft).toHaveBeenCalled()
        expect(Actions.sendDraft.calls.length).toBe 1

  describe "drag and drop", ->
    beforeEach ->
      useDraft.call @,
        to: [u1]
        subject: "Hello World"
        body: ""
        files: [f1]
      makeComposer.call(@)

    describe "_shouldAcceptDrop", ->
      it "should return true if the event is carrying native files", ->
        event =
          dataTransfer:
            files:[{'pretend':'imafile'}]
            types:[]
        expect(@composer._shouldAcceptDrop(event)).toBe(true)

      it "should return true if the event is carrying a non-native file URL", ->
        event =
          dataTransfer:
            files:[]
            types:['text/uri-list']
        spyOn(@composer, '_nonNativeFilePathForDrop').andReturn("file://one-file")

        expect(@composer._shouldAcceptDrop(event)).toBe(true)
        expect(@draft.files.length).toBe(1)

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

      spyOn(Actions, "fetchFile")

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

    firstStatus = @composer._isValidDraft()
    expect(firstStatus).toBe true
    Actions.sendDraft(DRAFT_CLIENT_ID)
    secondStatus = @composer._isValidDraft()
    expect(secondStatus).toBe false

  it "doesn't send twice in the main window", ->
    spyOn(Actions, "queueTask")
    spyOn(Actions, "sendDraft").andCallThrough()
    spyOn(NylasEnv, "isMainWindow").andReturn true
    useFullDraft.call(@)
    makeComposer.call(@)
    firstStatus = @composer._isValidDraft()
    expect(firstStatus).toBe true
    Actions.sendDraft(DRAFT_CLIENT_ID)
    secondStatus = @composer._isValidDraft()
    expect(secondStatus).toBe false
