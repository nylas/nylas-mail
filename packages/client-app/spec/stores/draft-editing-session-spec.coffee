Message = require('../../src/flux/models/message').default
Actions = require('../../src/flux/actions').default
DatabaseStore = require('../../src/flux/stores/database-store').default
DatabaseWriter = require('../../src/flux/stores/database-writer').default
DraftEditingSession = require '../../src/flux/stores/draft-editing-session'
DraftChangeSet = DraftEditingSession.DraftChangeSet
_ = require 'underscore'


xdescribe "DraftEditingSession Specs", ->
  describe "DraftChangeSet", ->
    beforeEach ->
      @onDidAddChanges = jasmine.createSpy('onDidAddChanges')
      @onWillAddChanges = jasmine.createSpy('onWillAddChanges')
      @commitResolve = null
      @commitResolves = []
      @onCommit = jasmine.createSpy('commit').andCallFake =>
        new Promise (resolve, reject) =>
          @commitResolves.push(resolve)
          @commitResolve = resolve

      @changeSet = new DraftChangeSet({
        onDidAddChanges: @onDidAddChanges,
        onWillAddChanges: @onWillAddChanges,
        onCommit: @onCommit,
      })
      @changeSet._pending =
        subject: 'Change to subject line'

    describe "teardown", ->
      it "should remove all of the pending and saving changes", ->
        @changeSet.teardown()
        expect(@changeSet._saving).toEqual({})
        expect(@changeSet._pending).toEqual({})

    describe "add", ->
      it "should mark that the draft is not pristine", ->
        @changeSet.add(body: 'Hello World!')
        expect(@changeSet._pending.pristine).toEqual(false)

      it "should add the changes to the _pending set", ->
        @changeSet.add(body: 'Hello World!')
        expect(@changeSet._pending.body).toEqual('Hello World!')

      describe "otherwise", ->
        it "should commit after thirty seconds", ->
          spyOn(@changeSet, 'commit')
          @changeSet.add({body: 'Hello World!'})
          expect(@changeSet.commit).not.toHaveBeenCalled()
          advanceClock(31000)
          expect(@changeSet.commit).toHaveBeenCalled()

    describe "commit", ->
      it "should resolve immediately if the pending set is empty", ->
        @changeSet._pending = {}
        waitsForPromise =>
          @changeSet.commit().then =>
            expect(@onCommit).not.toHaveBeenCalled()

      it "should move changes to the saving set", ->
        pendingBefore = _.extend({}, @changeSet._pending)
        expect(@changeSet._saving).toEqual({})
        @changeSet.commit()
        advanceClock()
        expect(@changeSet._pending).toEqual({})
        expect(@changeSet._saving).toEqual(pendingBefore)

      it "should call the commit handler and then clear the saving set", ->
        @changeSet.commit()
        advanceClock()
        expect(@changeSet._saving).not.toEqual({})
        @commitResolve()
        advanceClock()
        expect(@changeSet._saving).toEqual({})

      describe "concurrency", ->
        it "the commit function should always run serially", ->
          firstFulfilled = false
          secondFulfilled = false

          @changeSet._pending = {subject: 'A'}
          @changeSet.commit().then =>
            @changeSet._pending = {subject: 'B'}
            firstFulfilled = true
          @changeSet.commit().then =>
            secondFulfilled = true

          advanceClock()
          expect(firstFulfilled).toBe(false)
          expect(secondFulfilled).toBe(false)
          @commitResolves[0]()
          advanceClock()
          expect(firstFulfilled).toBe(true)
          expect(secondFulfilled).toBe(false)
          @commitResolves[1]()
          advanceClock()
          expect(firstFulfilled).toBe(true)
          expect(secondFulfilled).toBe(true)

    describe "applyToModel", ->
      it "should apply the saving and then the pending change sets, in that order", ->
        @changeSet._saving =  {subject: 'A', body: 'Basketb'}
        @changeSet._pending = {body: 'Basketball'}
        m = new Message()
        @changeSet.applyToModel(m)
        expect(m.subject).toEqual('A')
        expect(m.body).toEqual('Basketball')

  describe "DraftEditingSession", ->
    describe "constructor", ->
      it "should make a query to fetch the draft", ->
        spyOn(DatabaseStore, 'run').andCallFake =>
          new Promise (resolve, reject) =>
        session = new DraftEditingSession('client-id')
        expect(DatabaseStore.run).toHaveBeenCalled()

      describe "when given a draft object", ->
        beforeEach ->
          spyOn(DatabaseStore, 'run')
          @draft = new Message(draft: true, body: '123')
          @session = new DraftEditingSession('client-id', @draft)

        it "should not make a query for the draft", ->
          expect(DatabaseStore.run).not.toHaveBeenCalled()

        it "prepare should resolve without querying for the draft", ->
          waitsForPromise => @session.prepare().then =>
            expect(@session.draft()).toBeDefined()
            expect(DatabaseStore.run).not.toHaveBeenCalled()

    describe "teardown", ->
      it "should mark the session as destroyed", ->
        spyOn(DraftEditingSession.prototype, "prepare")
        session = new DraftEditingSession('client-id')
        session.teardown()
        expect(session._destroyed).toEqual(true)

    describe "prepare", ->
      beforeEach ->
        @draft = new Message(draft: true, body: '123', clientId: 'client-id')
        spyOn(DraftEditingSession.prototype, "prepare")
        @session = new DraftEditingSession('client-id')
        spyOn(@session, '_setDraft').andCallThrough()
        spyOn(DatabaseStore, 'run').andCallFake (modelQuery) =>
          Promise.resolve(@draft)
        jasmine.unspy(DraftEditingSession.prototype, "prepare")

      it "should call setDraft with the retrieved draft", ->
        waitsForPromise =>
          @session.prepare().then =>
            expect(@session._setDraft).toHaveBeenCalledWith(@draft)

      it "should resolve with the DraftEditingSession", ->
        waitsForPromise =>
          @session.prepare().then (val) =>
            expect(val).toBe(@session)

      describe "error handling", ->
        it "should reject if the draft session has already been destroyed", ->
          @session._destroyed = true
          waitsForPromise =>
            @session.prepare().then =>
              expect(false).toBe(true)
            .catch (val) =>
              expect(val instanceof Error).toBe(true)

        it "should reject if the draft cannot be found", ->
          @draft = null
          waitsForPromise =>
            @session.prepare().then =>
              expect(false).toBe(true)
            .catch (val) =>
              expect(val instanceof Error).toBe(true)

    describe "when a draft changes", ->
      beforeEach ->
        @draft = new Message(draft: true, clientId: 'client-id', body: 'A', subject: 'initial')
        @session = new DraftEditingSession('client-id', @draft)
        advanceClock()

        spyOn(DatabaseWriter.prototype, "persistModel").andReturn Promise.resolve()
        spyOn(Actions, "queueTask").andReturn Promise.resolve()

      it "should ignore the update unless it applies to the current draft", ->
        spyOn(@session, 'trigger')
        @session._onDraftChanged(objectClass: 'message', objects: [new Message()])
        expect(@session.trigger).not.toHaveBeenCalled()
        @session._onDraftChanged(objectClass: 'message', objects: [@draft])
        expect(@session.trigger).toHaveBeenCalled()

      it "should apply the update to the current draft", ->
        updatedDraft = @draft.clone()
        updatedDraft.subject = 'This is the new subject'
        spyOn(@session, '_setDraft')

        @session._onDraftChanged(objectClass: 'message', objects: [updatedDraft])
        expect(@session._setDraft).toHaveBeenCalled()
        draft = @session._setDraft.calls[0].args[0]
        expect(draft.subject).toEqual(updatedDraft.subject)

      it "atomically commits changes", ->
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(@draft))
        spyOn(DatabaseStore, 'inTransaction').andCallThrough()
        @session.changes.add({body: "123"})
        waitsForPromise =>
          @session.changes.commit().then =>
            expect(DatabaseStore.inTransaction).toHaveBeenCalled()
            expect(DatabaseStore.inTransaction.calls.length).toBe 1

      it "persist the applied changes", ->
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(@draft))
        @session.changes.add({body: "123"})
        waitsForPromise =>
          @session.changes.commit().then =>
            expect(DatabaseWriter.prototype.persistModel).toHaveBeenCalled()
            updated = DatabaseWriter.prototype.persistModel.calls[0].args[0]
            expect(updated.body).toBe "123"

      # Note: Syncback temporarily disabled
      #
      # it "queues a SyncbackDraftTask", ->
      #   spyOn(DatabaseStore, "run").andReturn(Promise.resolve(@draft))
      #   @session.changes.add({body: "123"})
      #   waitsForPromise =>
      #     @session.changes.commit().then =>
      #       expect(Actions.queueTask).toHaveBeenCalled()
      #       task = Actions.queueTask.calls[0].args[0]
      #       expect(task.draftClientId).toBe "client-id"

      it "doesn't queues a SyncbackDraftTask if no Syncback is passed", ->
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(@draft))
        waitsForPromise =>
          @session.changes.commit({noSyncback: true}).then =>
            expect(Actions.queueTask).not.toHaveBeenCalled()

      describe "when findBy does not return a draft", ->
        it "continues and persists it's local draft reference, so it is resaved and draft editing can continue", ->
          spyOn(DatabaseStore, "run").andReturn(Promise.resolve(null))
          @session.changes.add({body: "123"})
          waitsForPromise =>
            @session.changes.commit().then =>
              expect(DatabaseWriter.prototype.persistModel).toHaveBeenCalled()
              updated = DatabaseWriter.prototype.persistModel.calls[0].args[0]
              expect(updated.body).toBe "123"

      it "does nothing if the draft is marked as destroyed", ->
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(@draft))
        spyOn(DatabaseStore, 'inTransaction').andCallThrough()
        waitsForPromise =>
          @session._destroyed = true
          @session.changes.add({body: "123"})
          @session.changes.commit().then =>
            expect(DatabaseStore.inTransaction).not.toHaveBeenCalled()

    describe "draft pristine body", ->
      describe "when the draft given to the session is pristine", ->
        it "should return the initial body", ->
          pristineDraft = new Message(draft: true, body: 'Hiya', pristine: true, clientId: 'client-id')
          updatedDraft = pristineDraft.clone()
          updatedDraft.body = '123444'
          updatedDraft.pristine = false

          @session = new DraftEditingSession('client-id', pristineDraft)
          waitsForPromise =>
            @session._draftPromise.then =>
              @session._onDraftChanged(objectClass: 'message', objects: [updatedDraft])
              expect(@session.draftPristineBody()).toBe('Hiya')

      describe "when the draft given to the session is not pristine", ->
        it "should return null", ->
          dirtyDraft = new Message(draft: true, body: 'Hiya', pristine: false)
          @session = new DraftEditingSession('client-id', dirtyDraft)
          expect(@session.draftPristineBody()).toBe(null)
