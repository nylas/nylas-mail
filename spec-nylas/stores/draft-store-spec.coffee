Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
Contact = require '../../src/flux/models/contact'
ModelQuery = require '../../src/flux/models/query'
NamespaceStore = require '../../src/flux/stores/namespace-store'
DatabaseStore = require '../../src/flux/stores/database-store'
DraftStore = require '../../src/flux/stores/draft-store'
DraftStoreExtension = require '../../src/flux/stores/draft-store-extension'
TaskQueue = require '../../src/flux/stores/task-queue'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DestroyDraftTask = require '../../src/flux/tasks/destroy-draft'
Actions = require '../../src/flux/actions'
Utils = require '../../src/flux/models/utils'
_ = require 'underscore'

fakeThread = null
fakeMessage1 = null
fakeMessage2 = null
msgFromMe = null
msgWithReplyTo = null
msgWithReplyToDuplicates = null
fakeMessages = null

class TestExtension extends DraftStoreExtension
  @prepareNewDraft: (draft) ->
    draft.body = "Edited by TestExtension!" + draft.body

describe "DraftStore", ->
  beforeEach ->
    spyOn(atom, 'newWindow').andCallFake ->

  describe "creating drafts", ->
    beforeEach ->
      fakeThread = new Thread
        id: 'fake-thread-id'
        subject: 'Fake Subject'

      fakeMessage1 = new Message
        id: 'fake-message-1'
        to: [new Contact(email: 'ben@nylas.com'), new Contact(email: 'evan@nylas.com')]
        cc: [new Contact(email: 'mg@nylas.com'), new Contact(email: NamespaceStore.current().me().email)]
        bcc: [new Contact(email: 'recruiting@nylas.com')]
        from: [new Contact(email: 'customer@example.com', name: 'Customer')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 1'
        subject: 'Fake Subject'
        date: new Date(1415814587)

      fakeMessage2 = new Message
        id: 'fake-message-2'
        to: [new Contact(email: 'customer@example.com')]
        from: [new Contact(email: 'ben@nylas.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      msgFromMe = new Message
        id: 'fake-message-3'
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '3@3.com'), new Contact(email: '4@4.com')]
        bcc: [new Contact(email: '5@5.com'), new Contact(email: '6@6.com')]
        from: [new Contact(email: NamespaceStore.current().me().email)]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      msgWithReplyTo = new Message
        id: 'fake-message-reply-to'
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '3@3.com'), new Contact(email: '4@4.com')]
        bcc: [new Contact(email: '5@5.com'), new Contact(email: '6@6.com')]
        replyTo: [new Contact(email: 'reply-to@5.com'), new Contact(email: 'reply-to@6.com')]
        from: [new Contact(email: 'from@5.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 2'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      msgWithReplyToDuplicates = new Message
        id: 'fake-message-reply-to-duplicates'
        to: [new Contact(email: '1@1.com'), new Contact(email: '2@2.com')]
        cc: [new Contact(email: '1@1.com'), new Contact(email: '4@4.com')]
        from: [new Contact(email: 'reply-to@5.com')]
        replyTo: [new Contact(email: 'reply-to@5.com')]
        threadId: 'fake-thread-id'
        body: 'Fake Message Duplicates'
        subject: 'Re: Fake Subject'
        date: new Date(1415814587)

      fakeMessages =
        'fake-message-1': fakeMessage1
        'fake-message-3': msgFromMe
        'fake-message-2': fakeMessage2
        'fake-message-reply-to': msgWithReplyTo
        'fake-message-reply-to-duplicates': msgWithReplyToDuplicates

      spyOn(DatabaseStore, 'find').andCallFake (klass, id) ->
        query = new ModelQuery(klass, {id})
        spyOn(query, 'then').andCallFake (fn) ->
          return fn(fakeThread) if klass is Thread
          return fn(fakeMessages[id]) if klass is Message
          return fn(new Error('Not Stubbed'))
        query

      spyOn(DatabaseStore, 'run').andCallFake (query) ->
        return Promise.resolve(fakeMessage2) if query._klass is Message
        return Promise.reject(new Error('Not Stubbed'))
      spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
      spyOn(DatabaseStore, 'bindToLocalId')

    afterEach ->
      # Have to cleanup the DraftStoreProxy objects or we'll get a memory
      # leak error
      for id, session of DraftStore._draftSessions
        DraftStore._doneWithSession(session)

    describe "onComposeReply", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeReply({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseStore.persistModel.callCount > 0
        runs ->
          @model = DatabaseStore.persistModel.mostRecentCall.args[0]

      it "should include quoted text", ->
        expect(@model.body.indexOf('blockquote') > 0).toBe(true)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should address the message to the previous message's sender", ->
        expect(@model.to).toEqual(fakeMessage1.from)

      it "should set the replyToMessageId to the previous message's ids", ->
        expect(@model.replyToMessageId).toEqual(fakeMessage1.id)

    describe "onComposeReply", ->
      describe "when the message provided as context has one or more 'ReplyTo' recipients", ->
        it "addresses the draft to all of the message's 'ReplyTo' recipients", ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgWithReplyTo.id})
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            @model = DatabaseStore.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgWithReplyTo.replyTo)
            expect(@model.cc.length).toBe 0
            expect(@model.bcc.length).toBe 0

    describe "onComposeReply", ->
      describe "when the message provided as context was sent by the current user", ->
        it "addresses the draft to all of the last messages's 'To' recipients", ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgFromMe.id})
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            @model = DatabaseStore.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgFromMe.to)
            expect(@model.cc.length).toBe 0
            expect(@model.bcc.length).toBe 0

    describe "onComposeReplyAll", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseStore.persistModel.callCount > 0
        runs ->
          @model = DatabaseStore.persistModel.mostRecentCall.args[0]

      it "should include quoted text", ->
        expect(@model.body.indexOf('blockquote') > 0).toBe(true)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should address the message to the previous message's sender", ->
        expect(@model.to).toEqual(fakeMessage1.from)

      it "should cc everyone who was on the previous message in to or cc", ->
        ccEmails = @model.cc.map (cc) -> cc.email
        expect(ccEmails.sort()).toEqual([ 'ben@nylas.com', 'evan@nylas.com', 'mg@nylas.com'])

      it "should not include people who were bcc'd on the previous message", ->
        expect(@model.bcc).toEqual([])
        expect(@model.cc.indexOf(fakeMessage1.bcc[0])).toEqual(-1)

      it "should not include you when you were cc'd on the previous message", ->
        ccEmails = @model.cc.map (cc) -> cc.email
        expect(ccEmails.indexOf(NamespaceStore.current().me().email)).toEqual(-1)

      it "should set the replyToMessageId to the previous message's ids", ->
        expect(@model.replyToMessageId).toEqual(fakeMessage1.id)

    describe "onComposeReplyAll", ->
      describe "when the message provided as context has one or more 'ReplyTo' recipients", ->
        beforeEach ->
          runs ->
            DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgWithReplyTo.id})
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            @model = DatabaseStore.persistModel.mostRecentCall.args[0]

        it "addresses the draft to all of the message's 'ReplyTo' recipients", ->
          expect(@model.to).toEqual(msgWithReplyTo.replyTo)

        it "should not include the message's 'From' recipient in any field", ->
          all = [].concat(@model.to, @model.cc, @model.bcc)
          match = _.find all, (c) -> c.email is msgWithReplyTo.from[0].email
          expect(match).toEqual(undefined)

    describe "onComposeReplyAll", ->
      describe "when the message provided has one or more 'ReplyTo' recipients and duplicates in the To/Cc fields", ->
        it "should unique the to/cc fields", ->
          runs ->
            DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: msgWithReplyToDuplicates.id})
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            model = DatabaseStore.persistModel.mostRecentCall.args[0]
            ccEmails = model.cc.map (cc) -> cc.email
            expect(ccEmails.sort()).toEqual(['1@1.com', '2@2.com', '4@4.com'])
            toEmails = model.to.map (to) -> to.email
            expect(toEmails.sort()).toEqual(['reply-to@5.com'])

    describe "onComposeReplyAll", ->
      describe "when the message provided as context was sent by the current user", ->
        it "addresses the draft to all of the last messages's recipients", ->
          runs ->
            DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: msgFromMe.id})
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            @model = DatabaseStore.persistModel.mostRecentCall.args[0]
            expect(@model.to).toEqual(msgFromMe.to)
            expect(@model.cc).toEqual(msgFromMe.cc)
            expect(@model.bcc.length).toBe 0

    describe "onComposeForward", ->
      beforeEach ->
        runs ->
          DraftStore._onComposeForward({threadId: fakeThread.id, messageId: fakeMessage1.id})
        waitsFor ->
          DatabaseStore.persistModel.callCount > 0
        runs ->
          @model = DatabaseStore.persistModel.mostRecentCall.args[0]

      it "should include quoted text", ->
        expect(@model.body.indexOf('blockquote') > 0).toBe(true)
        expect(@model.body.indexOf(fakeMessage1.body) > 0).toBe(true)

      it "should not address the message to anyone", ->
        expect(@model.to).toEqual([])
        expect(@model.cc).toEqual([])
        expect(@model.bcc).toEqual([])

      it "should not set the replyToMessageId", ->
        expect(@model.replyToMessageId).toEqual(undefined)

    describe "_newMessageWithContext", ->
      beforeEach ->
        # A helper method that makes it easy to test _newMessageWithContext, which
        # is asynchronous and whose output is a model persisted to the database.
        @_callNewMessageWithContext = (context, attributesCallback, modelCallback) ->
          runs ->
            DraftStore._newMessageWithContext(context, attributesCallback)
          waitsFor ->
            DatabaseStore.persistModel.callCount > 0
          runs ->
            model = DatabaseStore.persistModel.mostRecentCall.args[0]
            modelCallback(model) if modelCallback

      it "should create a new message", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          expect(model.constructor).toBe(Message)

      it "should assign and save a local Id for the new message", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          expect(DatabaseStore.bindToLocalId).toHaveBeenCalled()

      it "should setup a draft session for the draftLocalId, so that a subsequent request for the session's draft resolves immediately.", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          [draft, localId] = DatabaseStore.bindToLocalId.mostRecentCall.args
          session = DraftStore.sessionForLocalId(localId).value()
          expect(session.draft()).toBe(draft)

      it "should set the subject of the new message automatically", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          {}
        , (model) ->
          expect(model.subject).toEqual("Re: Fake Subject")

      it "should apply attributes provided by the attributesCallback", ->
        @_callNewMessageWithContext {threadId: fakeThread.id}
        , (thread, message) ->
          subject: "Fwd: Fake subject"
          to: [new Contact(email: 'weird@example.com')]
        , (model) ->
          expect(model.subject).toEqual("Fwd: Fake subject")

      describe "extensions", ->
        beforeEach ->
          DraftStore.registerExtension(TestExtension)
        afterEach ->
          DraftStore.unregisterExtension(TestExtension)

        it "should give extensions a chance to customize the draft via ext.prepareNewDraft", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            {}
          , (model) ->
            expect(model.body.indexOf("Edited by TestExtension!")).toBe(0)

      describe "context", ->
        it "should accept `thread` or look up a thread when given `threadId`", ->
          @_callNewMessageWithContext {thread: fakeThread}
          , (thread, message) ->
            expect(thread).toBe(fakeThread)
            expect(DatabaseStore.find).not.toHaveBeenCalled()
            {}
          , (model) ->

          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            expect(thread).toBe(fakeThread)
            expect(DatabaseStore.find).toHaveBeenCalled()
            {}
          , (model) ->

        it "should accept `message` or look up a message when given `messageId`", ->
          @_callNewMessageWithContext {thread: fakeThread, message: fakeMessage1}
          , (thread, message) ->
            expect(message).toBe(fakeMessage1)
            expect(DatabaseStore.find).not.toHaveBeenCalled()
            {}
          , (model) ->

          @_callNewMessageWithContext {thread: fakeThread, messageId: fakeMessage1.id}
          , (thread, message) ->
            expect(message).toBe(fakeMessage1)
            expect(DatabaseStore.find).toHaveBeenCalled()
            {}
          , (model) ->


      describe "when a reply-to message is provided by the attributesCallback", ->
        it "should include quoted text in the new message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('gmail_quote') > 0).toBe(true)
            expect(model.body.indexOf('Fake Message 1') > 0).toBe(true)

        it "should include the `On ... wrote:` line", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.body.search(/On .+, at .+, Customer &lt;customer@example.com&gt; wrote/) > 0).toBe(true)

        it "should make the subject the subject of the message, not the thread", ->
          fakeMessage1.subject = "OLD SUBJECT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Re: OLD SUBJECT")

        it "should change the subject from Fwd: back to Re: if necessary", ->
          fakeMessage1.subject = "Fwd: This is my DRAFT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Re: This is my DRAFT")

        it "should only include the sender's name if it was available", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            replyToMessage: fakeMessage2
          , (model) ->
            expect(model.body.search(/On .+, at .+, ben@nylas.com wrote:/) > 0).toBe(true)

      describe "when a forward message is provided by the attributesCallback", ->
        it "should include quoted text in the new message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('gmail_quote') > 0).toBe(true)
            expect(model.body.indexOf('Fake Message 1') > 0).toBe(true)

        it "should include the `Begin forwarded message:` line", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.body.indexOf('Begin forwarded message') > 0).toBe(true)

        it "should make the subject the subject of the message, not the thread", ->
          fakeMessage1.subject = "OLD SUBJECT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Fwd: OLD SUBJECT")

        it "should change the subject from Re: back to Fwd: if necessary", ->
          fakeMessage1.subject = "Re: This is my DRAFT"
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage1
          , (model) ->
            expect(model.subject).toEqual("Fwd: This is my DRAFT")

        it "should print the headers of the original message", ->
          @_callNewMessageWithContext {threadId: fakeThread.id}
          , (thread, message) ->
            forwardMessage: fakeMessage2
          , (model) ->
            expect(model.body.indexOf('From: ben@nylas.com') > 0).toBe(true)
            expect(model.body.indexOf('Subject: Re: Fake Subject') > 0).toBe(true)
            expect(model.body.indexOf('To: customer@example.com') > 0).toBe(true)

      describe "attributesCallback", ->
        describe "when a threadId is provided", ->
          it "should receive the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id}
            , (thread, message) ->
              expect(thread).toEqual(fakeThread)
              {}

          it "should receive the last message in the fakeThread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id}
            , (thread, message) ->
              expect(message).toEqual(fakeMessage2)
              {}

        describe "when a threadId and messageId are provided", ->
          it "should receive the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id, messageId: fakeMessage1.id}
            , (thread, message) ->
              expect(thread).toEqual(fakeThread)
              {}

          it "should receive the desired message in the thread", ->
            @_callNewMessageWithContext {threadId: fakeThread.id, messageId: fakeMessage1.id}
            , (thread, message) ->
              expect(message).toEqual(fakeMessage1)
              {}

  describe "onDestroyDraft", ->
    beforeEach ->
      @draftReset = jasmine.createSpy('draft reset')
      @session =
        draft: ->
          pristine: false
        changes:
          commit: -> Promise.resolve()
          reset: @draftReset
        cleanup: ->
      DraftStore._draftSessions = {"abc": @session}
      spyOn(Actions, 'queueTask')

    it "should reset the draft session, ensuring no more saves are made", ->
      DraftStore._onDestroyDraft('abc')
      expect(@draftReset).toHaveBeenCalled()

    it "should not throw if the draft session is not in the window", ->
      expect ->
        DraftStore._onDestroyDraft('other')
      .not.toThrow()

    it "should queue a destroy draft task", ->
      DraftStore._onDestroyDraft('abc')
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    it "should clean up the draft session", ->
      spyOn(DraftStore, '_doneWithSession')
      DraftStore._onDestroyDraft('abc')
      expect(DraftStore._doneWithSession).toHaveBeenCalledWith(@session)

    it "should close the window if it's a popout", ->
      spyOn(atom, "close")
      spyOn(DraftStore, "_isPopout").andReturn true
      DraftStore._onDestroyDraft('abc')
      expect(atom.close).toHaveBeenCalled()

    it "should NOT close the window if isn't a popout", ->
      spyOn(atom, "close")
      spyOn(DraftStore, "_isPopout").andReturn false
      DraftStore._onDestroyDraft('abc')
      expect(atom.close).not.toHaveBeenCalled()

  describe "before unloading", ->
    it "should destroy pristine drafts", ->
      DraftStore._draftSessions = {"abc": {
        changes: {}
        draft: ->
          pristine: true
      }}

      spyOn(Actions, 'queueTask')
      DraftStore._onBeforeUnload()
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    describe "when drafts return unresolved commit promises", ->
      beforeEach ->
        @resolve = null
        DraftStore._draftSessions = {"abc": {
          changes:
            commit: => new Promise (resolve, reject) => @resolve = resolve
          draft: ->
            pristine: false
        }}

      it "should return false and call window.close itself", ->
        spyOn(DraftStore, '_onBeforeUnloadComplete')
        expect(DraftStore._onBeforeUnload()).toBe(false)
        expect(DraftStore._onBeforeUnloadComplete).not.toHaveBeenCalled()
        @resolve()
        advanceClock(1000)
        expect(DraftStore._onBeforeUnloadComplete).toHaveBeenCalled()

    describe "when drafts return immediately fulfilled commit promises", ->
      beforeEach ->
        DraftStore._draftSessions = {"abc": {
          changes:
            commit: => Promise.resolve()
          draft: ->
            pristine: false
        }}

      it "should still wait one tick before firing atom.close again", ->
        spyOn(DraftStore, '_onBeforeUnloadComplete')
        expect(DraftStore._onBeforeUnload()).toBe(false)
        expect(DraftStore._onBeforeUnloadComplete).not.toHaveBeenCalled()
        advanceClock()
        expect(DraftStore._onBeforeUnloadComplete).toHaveBeenCalled()

    describe "when there are no drafts", ->
      beforeEach ->
        DraftStore._draftSessions = {}

      it "should return true and allow the window to close", ->
        expect(DraftStore._onBeforeUnload()).toBe(true)

  describe "sending a draft", ->
    draftLocalId = "local-123"
    beforeEach ->
      DraftStore._draftSessions = {}
      proxy =
        prepare: -> Promise.resolve(proxy)
        cleanup: ->
        draft: -> {}
        changes:
          commit: -> Promise.resolve()
      DraftStore._draftSessions[draftLocalId] = proxy
      spyOn(DraftStore, "_doneWithSession").andCallThrough()
      spyOn(DraftStore, "trigger")
      TaskQueue._queue = []

    it "sets the sending state when sending", ->
      spyOn(atom, "isMainWindow").andReturn true
      spyOn(TaskQueue, "_updateSoon")
      spyOn(Actions, "queueTask").andCallThrough()
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor ->
        Actions.queueTask.calls.length > 0
      runs ->
        expect(DraftStore.isSendingDraft(draftLocalId)).toBe true
        expect(DraftStore.trigger).toHaveBeenCalled()

    it "returns false if the draft hasn't been seen", ->
      spyOn(atom, "isMainWindow").andReturn true
      expect(DraftStore.isSendingDraft(draftLocalId)).toBe false

    it "closes the window if it's a popout", ->
      spyOn(atom, "getWindowType").andReturn "composer"
      spyOn(atom, "isMainWindow").andReturn false
      spyOn(atom, "close")
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor "Atom to close", ->
        atom.close.calls.length > 0

    it "doesn't close the window if it's inline", ->
      spyOn(atom, "getWindowType").andReturn "other"
      spyOn(atom, "isMainWindow").andReturn false
      spyOn(atom, "close")
      spyOn(DraftStore, "_isPopout").andCallThrough()
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor ->
        DraftStore._isPopout.calls.length > 0
      runs ->
        expect(atom.close).not.toHaveBeenCalled()

    it "queues a SendDraftTask", ->
      spyOn(Actions, "queueTask")
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor ->
        DraftStore._doneWithSession.calls.length > 0
      runs ->
        expect(Actions.queueTask).toHaveBeenCalled()
        task = Actions.queueTask.calls[0].args[0]
        expect(task instanceof SendDraftTask).toBe true
        expect(task.draftLocalId).toBe draftLocalId
        expect(task.fromPopout).toBe false

    it "queues a SendDraftTask with popout info", ->
      spyOn(atom, "getWindowType").andReturn "composer"
      spyOn(atom, "isMainWindow").andReturn false
      spyOn(atom, "close")
      spyOn(Actions, "queueTask")
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor ->
        DraftStore._doneWithSession.calls.length > 0
      runs ->
        expect(Actions.queueTask).toHaveBeenCalled()
        task = Actions.queueTask.calls[0].args[0]
        expect(task.fromPopout).toBe true

  describe "session cleanup", ->
    beforeEach ->
      @draftCleanup = jasmine.createSpy('draft cleanup')
      @session =
        draftLocalId: "abc"
        draft: ->
          pristine: false
        changes:
          commit: -> Promise.resolve()
          reset: ->
        cleanup: @draftCleanup
      DraftStore._draftSessions = {"abc": @session}
      DraftStore._doneWithSession(@session)

    it "removes from the list of draftSessions", ->
      expect(DraftStore._draftSessions["abc"]).toBeUndefined()

    it "Calls cleanup on the session", ->
      expect(@draftCleanup).toHaveBeenCalled

  describe "mailto handling", ->
    describe "extensions", ->
      beforeEach ->
        DraftStore.registerExtension(TestExtension)
      afterEach ->
        DraftStore.unregisterExtension(TestExtension)

      it "should give extensions a chance to customize the draft via ext.prepareNewDraft", ->
        received = null
        spyOn(DatabaseStore, 'persistModel').andCallFake (draft) ->
          received = draft
          Promise.resolve()
        DraftStore._onHandleMailtoLink('mailto:bengotow@gmail.com')
        expect(received.body.indexOf("Edited by TestExtension!")).toBe(0)

    it "should correctly instantiate drafts for a wide range of mailto URLs", ->
      received = null
      spyOn(DatabaseStore, 'persistModel').andCallFake (draft) ->
        received = draft
        Promise.resolve()

      links = [
        'mailto:'
        'mailto://bengotow@gmail.com'
        'mailto:bengotow@gmail.com'
        'mailto:?subject=%1z2a', # fails uriDecode
        'mailto:?subject=%52z2a', # passes uriDecode
        'mailto:?subject=Martha Stewart',
        'mailto:?subject=Martha Stewart&cc=cc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=bcc@nylas.com',
        'mailto:bengotow@gmail.com?subject=Martha%20Stewart&cc=cc@nylas.com&bcc=Ben <bcc@nylas.com>',
        'mailto:Ben Gotow <bengotow@gmail.com>,Shawn <shawn@nylas.com>?subject=Yes this is really valid'
        'mailto:Ben%20Gotow%20<bengotow@gmail.com>,Shawn%20<shawn@nylas.com>?subject=Yes%20this%20is%20really%20valid'
        'mailto:Reply <d+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com>?subject=Nilas%20Message%20to%20Customers',
      ]
      expected = [
        new Message(),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')]
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')]
        ),
        new Message(
          subject: '%1z2a'
        ),
        new Message(
          subject: 'Rz2a'
        ),
        new Message(
          subject: 'Martha Stewart'
        ),
        new Message(
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')],
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          bcc: [new Contact(name: 'bcc@nylas.com', email: 'bcc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'bengotow@gmail.com', email: 'bengotow@gmail.com')],
          cc: [new Contact(name: 'cc@nylas.com', email: 'cc@nylas.com')],
          bcc: [new Contact(name: 'Ben', email: 'bcc@nylas.com')],
          subject: 'Martha Stewart'
        ),
        new Message(
          to: [new Contact(name: 'Ben Gotow', email: 'bengotow@gmail.com'), new Contact(name: 'Shawn', email: 'shawn@nylas.com')],
          subject: 'Yes this is really valid'
        ),
        new Message(
          to: [new Contact(name: 'Ben Gotow', email: 'bengotow@gmail.com'), new Contact(name: 'Shawn', email: 'shawn@nylas.com')],
          subject: 'Yes this is really valid'
        ),
        new Message(
          to: [new Contact(name: 'Reply', email: 'd+AORGpRdj0KXKUPBE1LoI0a30F10Ahj3wu3olS-aDk5_7K5Wu6WqqqG8t1HxxhlZ4KEEw3WmrSdtobgUq57SkwsYAH6tG57IrNqcQR0K6XaqLM2nGNZ22D2k@docs.google.com')],
          subject: 'Nilas Message to Customers'
        )
      ]

      for link, idx in links
        DraftStore._onHandleMailtoLink(link)
        expectedDraft = expected[idx]
        expect(received['subject']).toEqual(expectedDraft['subject'])
        for attr in ['to', 'cc', 'bcc', 'subject']
          for contact, jdx in received[attr]
            expectedContact = expectedDraft[attr][jdx]
            expect(contact.email).toEqual(expectedContact.email)
            expect(contact.name).toEqual(expectedContact.name)
