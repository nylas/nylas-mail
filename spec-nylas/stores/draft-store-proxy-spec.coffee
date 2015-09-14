Message = require '../../src/flux/models/message'
DatabaseStore = require '../../src/flux/stores/database-store'
DraftStoreProxy = require '../../src/flux/stores/draft-store-proxy'
DraftChangeSet = DraftStoreProxy.DraftChangeSet
_ = require 'underscore'

describe "DraftChangeSet", ->
  beforeEach ->
    @triggerSpy = jasmine.createSpy('trigger')
    @commitResolve = null
    @commitResolves = []
    @commitSpy = jasmine.createSpy('commit').andCallFake =>
      new Promise (resolve, reject) =>
        @commitResolves.push(resolve)
        @commitResolve = resolve

    @changeSet = new DraftChangeSet(@triggerSpy, @commitSpy)
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

    describe "when the immediate option is passed", ->
      it "should commit", ->
        spyOn(@changeSet, 'commit')
        @changeSet.add({body: 'Hello World!'}, {immediate: true})
        expect(@changeSet.commit).toHaveBeenCalled()

    describe "otherwise", ->
      it "should commit after five seconds", ->
        spyOn(@changeSet, 'commit')
        @changeSet.add({body: 'Hello World!'})
        expect(@changeSet.commit).not.toHaveBeenCalled()
        advanceClock(6000)
        expect(@changeSet.commit).toHaveBeenCalled()

  describe "commit", ->
    it "should resolve immediately if the pending set is empty", ->
      @changeSet._pending = {}
      waitsForPromise =>
        @changeSet.commit().then =>
          expect(@commitSpy).not.toHaveBeenCalled()

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

describe "DraftStoreProxy", ->
  describe "constructor", ->
    it "should make a query to fetch the draft", ->
      spyOn(DatabaseStore, 'run').andCallFake =>
        new Promise (resolve, reject) =>
      proxy = new DraftStoreProxy('client-id')
      expect(DatabaseStore.run).toHaveBeenCalled()

    describe "when given a draft object", ->
      beforeEach ->
        spyOn(DatabaseStore, 'run')
        @draft = new Message(draft: true, body: '123')
        @proxy = new DraftStoreProxy('client-id', @draft)

      it "should not make a query for the draft", ->
        expect(DatabaseStore.run).not.toHaveBeenCalled()

      it "should immediately make the draft available", ->
        expect(@proxy.draft()).toEqual(@draft)

  describe "teardown", ->
    it "should mark the session as destroyed", ->
      proxy = new DraftStoreProxy('client-id')
      proxy.teardown()
      expect(proxy._destroyed).toEqual(true)

  describe "prepare", ->
    beforeEach ->
      @draft = new Message(draft: true, body: '123', clientId: 'client-id')
      @proxy = new DraftStoreProxy('client-id')
      spyOn(@proxy, '_setDraft')
      spyOn(DatabaseStore, 'run').andCallFake =>
        Promise.resolve(@draft)
      @proxy._draftPromise = null

    it "should call setDraft with the retrieved draft", ->
      waitsForPromise =>
        @proxy.prepare().then =>
          expect(@proxy._setDraft).toHaveBeenCalledWith(@draft)

    it "should resolve with the DraftStoreProxy", ->
      waitsForPromise =>
        @proxy.prepare().then (val) =>
          expect(val).toBe(@proxy)

    describe "error handling", ->
      it "should reject if the draft session has already been destroyed", ->
        @proxy._destroyed = true
        waitsForPromise =>
          @proxy.prepare().then =>
            expect(false).toBe(true)
          .catch (val) =>
            expect(val instanceof Error).toBe(true)

      it "should reject if the draft cannot be found", ->
        @draft = null
        waitsForPromise =>
          @proxy.prepare().then =>
            expect(false).toBe(true)
          .catch (val) =>
            expect(val instanceof Error).toBe(true)

  describe "when a draft changes", ->
    beforeEach ->
      @draft = new Message(draft: true, clientId: 'client-id', body: 'A', subject: 'initial')
      @proxy = new DraftStoreProxy('client-id', @draft)

    it "should ignore the update unless it applies to the current draft", ->
      spyOn(@proxy, 'trigger')
      @proxy._onDraftChanged(objectClass: 'message', objects: [new Message()])
      expect(@proxy.trigger).not.toHaveBeenCalled()
      @proxy._onDraftChanged(objectClass: 'message', objects: [@draft])
      expect(@proxy.trigger).toHaveBeenCalled()

    it "should apply the update to the current draft", ->
      updatedDraft = @draft.clone()
      updatedDraft.subject = 'This is the new subject'

      @proxy._onDraftChanged(objectClass: 'message', objects: [updatedDraft])
      expect(@proxy.draft().subject).toEqual(updatedDraft.subject)

  describe "draft pristine body", ->
    describe "when the draft given to the session is pristine", ->
      it "should return the initial body", ->
        pristineDraft = new Message(draft: true, body: 'Hiya', pristine: true, clientId: 'client-id')
        updatedDraft = pristineDraft.clone()
        updatedDraft.body = '123444'
        updatedDraft.pristine = false

        @proxy = new DraftStoreProxy('client-id', pristineDraft)
        @proxy._onDraftChanged(objectClass: 'message', objects: [updatedDraft])
        expect(@proxy.draftPristineBody()).toBe('Hiya')

    describe "when the draft given to the session is not pristine", ->
      it "should return null", ->
        dirtyDraft = new Message(draft: true, body: 'Hiya', pristine: false)
        @proxy = new DraftStoreProxy('client-id', dirtyDraft)
        expect(@proxy.draftPristineBody()).toBe(null)
