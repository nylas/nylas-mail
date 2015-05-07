Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
Contact = require '../../src/flux/models/contact'
ModelQuery = require '../../src/flux/models/query'
NamespaceStore = require '../../src/flux/stores/namespace-store'
DatabaseStore = require '../../src/flux/stores/database-store'
DraftStore = require '../../src/flux/stores/draft-store'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DestroyDraftTask = require '../../src/flux/tasks/destroy-draft'
Actions = require '../../src/flux/actions'
_ = require 'underscore-plus'

fakeThread = null
fakeMessage1 = null
fakeMessage2 = null
msgFromMe = null
fakeMessages = null

describe "DraftStore", ->
  describe "creating drafts", ->
    beforeEach ->
      fakeThread = new Thread
        id: 'fake-thread-id'
        subject: 'Fake Subject'

      fakeMessage1 = new Message
        id: 'fake-message-1'
        to: [new Contact(email: 'ben@nilas.com'), new Contact(email: 'evan@nilas.com')]
        cc: [new Contact(email: 'mg@nilas.com'), new Contact(email: NamespaceStore.current().me().email)]
        bcc: [new Contact(email: 'recruiting@nilas.com')]
        from: [new Contact(email: 'customer@example.com', name: 'Customer')]
        threadId: 'fake-thread-id'
        body: 'Fake Message 1'
        subject: 'Fake Subject'
        date: new Date(1415814587)

      fakeMessage2 = new Message
        id: 'fake-message-2'
        to: [new Contact(email: 'customer@example.com')]
        from: [new Contact(email: 'ben@nilas.com')]
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

      fakeMessages =
        'fake-message-1': fakeMessage1
        'fake-message-3': msgFromMe
        'fake-message-2': fakeMessage2

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
      spyOn(DatabaseStore, 'persistModel')

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

    describe "when the reply-to address is you", ->
      it "on reply sends to all of the last messages's to recipients only", ->
        runs ->
          DraftStore._onComposeReply({threadId: fakeThread.id, messageId: msgFromMe.id})
        waitsFor ->
          DatabaseStore.persistModel.callCount > 0
        runs ->
          @model = DatabaseStore.persistModel.mostRecentCall.args[0]
          expect(@model.to).toEqual(msgFromMe.to)
          expect(@model.cc.length).toBe 0
          expect(@model.bcc.length).toBe 0

      it "on reply-all sends to all of the last messages's recipients", ->
        runs ->
          DraftStore._onComposeReplyAll({threadId: fakeThread.id, messageId: msgFromMe.id})
        waitsFor ->
          DatabaseStore.persistModel.callCount > 0
        runs ->
          @model = DatabaseStore.persistModel.mostRecentCall.args[0]
          expect(@model.to).toEqual(msgFromMe.to)
          expect(@model.cc).toEqual(msgFromMe.cc)
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
        expect(ccEmails.sort()).toEqual([ 'ben@nilas.com', 'evan@nilas.com', 'mg@nilas.com'])

      it "should not include people who were bcc'd on the previous message", ->
        expect(@model.bcc).toEqual([])
        expect(@model.cc.indexOf(fakeMessage1.bcc[0])).toEqual(-1)

      it "should not include you when you were cc'd on the previous message", ->
        ccEmails = @model.cc.map (cc) -> cc.email
        expect(ccEmails.indexOf(NamespaceStore.current().me().email)).toEqual(-1)

      it "should set the replyToMessageId to the previous message's ids", ->
        expect(@model.replyToMessageId).toEqual(fakeMessage1.id)

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
            expect(model.body.search(/On .+, at .+, ben@nilas.com wrote:/) > 0).toBe(true)

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
            expect(model.body.indexOf('From: ben@nilas.com') > 0).toBe(true)
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
      spyOn(Actions, 'queueTask')
      DraftStore._draftSessions = {"abc":{
        draft: ->
          pristine: false
        changes:
          commit: -> Promise.resolve()
          reset: @draftReset
        cleanup: ->
      }}

    it "should reset the draft session, ensuring no more saves are made", ->
      DraftStore._onDestroyDraft('abc')
      expect(@draftReset).toHaveBeenCalled()

    it "should not do anything if the draft session is not in the window", ->
      expect ->
        DraftStore._onDestroyDraft('other')
      .not.toThrow()
      expect(@draftReset).not.toHaveBeenCalled()

    it "should queue a destroy draft task", ->
      DraftStore._onDestroyDraft('abc')
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    it "should clean up the draft session", ->
      spyOn(DraftStore, 'cleanupSessionForLocalId')
      DraftStore._onDestroyDraft('abc')
      expect(DraftStore.cleanupSessionForLocalId).toHaveBeenCalledWith('abc')

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
        spyOn(window, 'close')
        expect(DraftStore._onBeforeUnload()).toBe(false)
        runs ->
        @resolve()
        waitsFor ->
          window.close.callCount > 0
        runs ->
          expect(window.close).toHaveBeenCalled()

    describe "when no drafts return unresolved commit promises", ->
      beforeEach ->
        DraftStore._draftSessions = {"abc":{
          changes:
            commit: -> Promise.resolve()
          draft: ->
            pristine: false
        }}

      it "should return true and allow the window to close", ->
        expect(DraftStore._onBeforeUnload()).toBe(true)

  describe "sending a draft", ->
    draftLocalId = "local-123"
    beforeEach ->
      DraftStore._sendingState = {}
      DraftStore._draftSessions = {}
      DraftStore._draftSessions[draftLocalId] =
        prepare: -> Promise.resolve()
        cleanup: ->
        draft: -> {}
        changes:
          commit: -> Promise.resolve()
      spyOn(DraftStore, "trigger")

    it "sets the sending state when sending", ->
      DraftStore._onSendDraft(draftLocalId)
      expect(DraftStore.sendingState(draftLocalId)).toBe true
      expect(DraftStore.trigger).toHaveBeenCalled()

    it "returns false if the draft hasn't been seen", ->
      expect(DraftStore.sendingState(draftLocalId)).toBe false

    it "resets the sending state on success", ->
      waitsForPromise ->
        DraftStore._onSendDraft(draftLocalId).then ->
          expect(DraftStore.sendingState(draftLocalId)).toBe true

          DraftStore._onSendDraftSuccess({draftLocalId})
          expect(DraftStore.sendingState(draftLocalId)).toBe false
          expect(DraftStore.trigger).toHaveBeenCalled()

    it "resets the sending state on error", ->
      waitsForPromise ->
        DraftStore._onSendDraft(draftLocalId).then ->
          expect(DraftStore.sendingState(draftLocalId)).toBe true
          DraftStore._onSendDraftError(draftLocalId)
          expect(DraftStore.sendingState(draftLocalId)).toBe false
          expect(DraftStore.trigger).toHaveBeenCalled()

    it "closes the window if it's a popout", ->
      spyOn(atom, "getWindowType").andReturn "composer"
      spyOn(atom, "isMainWindow").andReturn false
      spyOn(atom, "close")
      runs ->
        DraftStore._onSendDraft(draftLocalId)
      waitsFor "Atom to close", ->
        advanceClock(1000)
        atom.close.calls.length > 0

    it "doesn't close the window if it's inline", ->
      spyOn(atom, "getWindowType").andReturn "other"
      spyOn(atom, "isMainWindow").andReturn false
      spyOn(atom, "close")
      waitsForPromise ->
        DraftStore._onSendDraft(draftLocalId).then ->
          expect(atom.close).not.toHaveBeenCalled()

    it "queues a SendDraftTask", ->
      spyOn(Actions, "queueTask")
      waitsForPromise ->
        DraftStore._onSendDraft(draftLocalId).then ->
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
      waitsForPromise ->
        DraftStore._onSendDraft(draftLocalId).then ->
          expect(Actions.queueTask).toHaveBeenCalled()
          task = Actions.queueTask.calls[0].args[0]
          expect(task.fromPopout).toBe true

  describe "cleanupSessionForLocalId", ->
    it "should destroy the draft if it is pristine", ->
      DraftStore._draftSessions = {"abc":{
        draft: ->
          pristine: true
        cleanup: ->
      }}
      spyOn(Actions, 'queueTask')
      DraftStore.cleanupSessionForLocalId('abc')
      expect(Actions.queueTask).toHaveBeenCalled()
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true)

    it "should not do anything bad if the session does not exist", ->
      expect ->
        DraftStore.cleanupSessionForLocalId('dne')
      .not.toThrow()

    describe "when in the popout composer", ->
      beforeEach ->
        spyOn(atom, "getWindowType").andReturn "composer"
        spyOn(atom, "isMainWindow").andReturn false
        DraftStore._draftSessions = {"abc":{
          draft: ->
            pristine: false
          cleanup: ->
        }}

      it "should close the composer window", ->
        spyOn(atom, 'close')
        DraftStore.cleanupSessionForLocalId('abc')
        advanceClock(1000)
        expect(atom.close).toHaveBeenCalled()

      it "should not close the composer window if the draft session is not in the window", ->
        spyOn(atom, 'close')
        DraftStore.cleanupSessionForLocalId('other-random-draft-id')
        advanceClock(1000)
        expect(atom.close).not.toHaveBeenCalled()

    describe "when it is in a main window", ->
      beforeEach ->
        @cleanup = jasmine.createSpy('cleanup')
        spyOn(atom, "isMainWindow").andReturn true
        DraftStore._draftSessions = {"abc":{
          draft: ->
            pristine: false
          cleanup: @cleanup
        }}

      it "should call proxy.cleanup() to unlink listeners", ->
        DraftStore.cleanupSessionForLocalId('abc')
        expect(@cleanup).toHaveBeenCalled()

      it "should remove the proxy from the sessions list", ->
        DraftStore.cleanupSessionForLocalId('abc')
        expect(DraftStore._draftSessions).toEqual({})

