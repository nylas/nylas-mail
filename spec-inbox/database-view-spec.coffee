_ = require 'underscore-plus'
EventEmitter = require('events').EventEmitter
proxyquire = require 'proxyquire'
Thread = require '../src/flux/models/thread'
Message = require '../src/flux/models/message'

DatabaseStore = require '../src/flux/stores/database-store'
DatabaseView = proxyquire '../src/flux/stores/database-view',
  DatabaseStore: DatabaseStore

describe "DatabaseView", ->
  beforeEach ->
    @queries = []
    spyOn(DatabaseStore, 'run').andCallFake (query) =>
      new Promise (resolve, reject) =>
        query.resolve = resolve
        @queries.push(query)

  describe "constructor", ->
    it "should require a model class", ->
      expect(( -> new DatabaseView())).toThrow()
      expect(( -> new DatabaseView(Thread))).not.toThrow()
      view = new DatabaseView(Thread)
      expect(view.klass).toBe(Thread)

    it "should optionally populate matchers and includes", ->
      config =
        matchers: [Message.attributes.namespaceId.equal('asd')]
        includes: [Message.attributes.body]
      view = new DatabaseView(Message, config)
      expect(view._matchers).toEqual(config.matchers)
      expect(view._includes).toEqual(config.includes)

    it "should optionally accept a metadata provider", ->
      provider = ->
      view = new DatabaseView(Message, {}, provider)
      expect(view._itemMetadataProvider).toEqual(provider)

    it "should initialize the row count to -1", ->
      view = new DatabaseView(Message)
      expect(view.count()).toBe(-1)

    it "should immediately start fetching a row count and page one", ->
      config =
        matchers: [Message.attributes.namespaceId.equal('asd')]
      view = new DatabaseView(Message, config)

      # Count query
      expect(@queries.length).toEqual(2)
      expect(@queries[0]._count).toEqual(true)
      expect(@queries[0]._matchers).toEqual(config.matchers)

      # Items query
      expect(@queries[1]._matchers).toEqual(config.matchers)
      expect(@queries[1]._range).toEqual({offset:0, limit:view._pageSize})

  describe "instance methods", ->
    beforeEach ->
      config =
        matchers: [Message.attributes.namespaceId.equal('asd')]
      @view = new DatabaseView(Message, config)
      @view._pages =
        0:
          items: [{id: 'a'}, {id: 'b'}, {id: 'c'}]
          metadata: {'a': 'a-metadata', 'b': 'b-metadata', 'c': 'c-metadata'}
          loaded: true
        1:
          items: [{id: 'd'}, {id: 'e'}, {id: 'f'}]
          metadata: {'d': 'd-metadata', 'e': 'e-metadata', 'f': 'f-metadata'}
          loaded: true
      @view._count = 1
      spyOn(@view, 'invalidateRetainedRange').andCallFake ->

    describe "setItemMetadataProvider", ->
      it "should empty the page cache and re-fetch all pages", ->
        @view.setItemMetadataProvider( -> false)
        expect(@view._pages).toEqual({})
        expect(@view.invalidateRetainedRange).toHaveBeenCalled()

    describe "setMatchers", ->
      it "should reset the row count", ->
        @view.setMatchers([])
        expect(@view._count).toEqual(-1)

      it "should empty the page cache and re-fetch all pages", ->
        @view.setMatchers([])
        expect(@view._pages).toEqual({})
        expect(@view.invalidateRetainedRange).toHaveBeenCalled()

    describe "setIncludes", ->
      it "should empty the page cache and re-fetch all pages", ->
        @view.setIncludes([])
        expect(@view._pages).toEqual({})
        expect(@view.invalidateRetainedRange).toHaveBeenCalled()


    describe "invalidate", ->
      it "should clear the metadata cache for each page and re-fetch", ->
        @view.invalidate({shallow: false})
        expect(@view.invalidateRetainedRange).toHaveBeenCalled()
        expect(@view._pages[0].metadata).toEqual({})

      describe "when the shallow option is provided", ->
        it "should refetch items in each page, but not flush the item metadata cache", ->
          beforeMetadata = @view._pages[0].metadata
          @view.invalidate({shallow: true})
          expect(@view.invalidateRetainedRange).toHaveBeenCalled()
          expect(@view._pages[0].metadata).toEqual(beforeMetadata)

    describe "invalidateItems", ->
      it "should clear cached metadata for just the items whose ids are provided", ->
        @view.invalidateItems(['b', 'e'])
        expect(@view._pages[0].metadata).toEqual({'a': 'a-metadata', 'c': 'c-metadata'})
        expect(@view._pages[1].metadata).toEqual({'d': 'd-metadata', 'f': 'f-metadata'})

      it "should invalidate the entire range, since individual item changes can change sort orders, etc.", ->
        spyOn(@view, 'retrievePage')
        @view.invalidateItems(['e'])
        expect(@view.invalidateRetainedRange).toHaveBeenCalled()

    describe "cullPages", ->
      beforeEach ->
        @view._retainedRange = {start: 200, end: 399}
        @view._pages = {}
        for i in [0..9]
          @view._pages[i] =
            items: [{id: 'a'}, {id: 'b'}, {id: 'c'}]
            metadata: {'a': 'a-metadata', 'b': 'b-metadata', 'c': 'c-metadata'}
            loaded: true

      it "should not remove pages in the retained range", ->
        @view.cullPages()
        expect(@view._pages[2]).toBeDefined()
        expect(@view._pages[3]).toBeDefined()
        expect(@view._pages[4]).toBeDefined()

      it "should remove pages far from the retained range", ->
        @view.cullPages()
        expect(@view._pages[7]).not.toBeDefined()
        expect(@view._pages[8]).not.toBeDefined()
        expect(@view._pages[9]).not.toBeDefined()

  describe "retrievePage", ->
    beforeEach ->
      @config =
        matchers: [Message.attributes.namespaceId.equal('asd')]
      @view = new DatabaseView(Message, @config)
      @queries = []

    it "should initialize the page and set loading to true", ->
      @view.retrievePage(0)
      expect(@view._pages[0]).toEqual({metadata: {}, items: [], loading: true})

    it "should make a database query for the correct item range", ->
      @view.retrievePage(2)
      expect(@queries.length).toBe(1)
      expect(@queries[0]._range).toEqual({offset: @view._pageSize * 2, limit: @view._pageSize})
      expect(@queries[0]._matchers).toEqual(@config.matchers)

    describe "once the database request has completed", ->
      beforeEach ->
        @view.retrievePage(0)
        @completeQuery = =>
          @items = [{id: 'model-a'}, {id: 'model-b'}, {id: 'model-c'}]
          @queries[0].resolve(@items)
          @queries = []
        spyOn(@view._emitter, 'emit')

      it "should populate the page items and call trigger", ->
        runs ->
          @completeQuery()
        waitsFor ->
          @view._emitter.emit.callCount > 0
        runs ->
          expect(@view._pages[0].items).toEqual(@items)
          expect(@view._emitter.emit).toHaveBeenCalled()

      it "should set loading to false for the page", ->
        runs ->
          expect(@view._pages[0].loading).toEqual(true)
          @completeQuery()
        waitsFor ->
          @view._emitter.emit.callCount > 0
        runs ->
          expect(@view._pages[0].loading).toEqual(false)

      describe "if an item metadata provider is configured", ->
        beforeEach ->
          @view._itemMetadataProvider = (item) ->
            Promise.resolve('metadata-for-'+item.id)

        it "should set .metadata of each item", ->
          runs ->
            @completeQuery()
          waitsFor ->
            @view._emitter.emit.callCount > 0
          runs ->
            expect(@view._pages[0].items[0].metadata).toEqual('metadata-for-model-a')
            expect(@view._pages[0].items[1].metadata).toEqual('metadata-for-model-b')

        it "should cache the metadata on the page object", ->
          runs ->
            @completeQuery()
          waitsFor ->
            @view._emitter.emit.callCount > 0
          runs ->
            expect(@view._pages[0].metadata).toEqual
              'model-a': 'metadata-for-model-a'
              'model-b': 'metadata-for-model-b'
              'model-c': 'metadata-for-model-c'

        it "should always wait for metadata promises to resolve", ->
          @resolves = []
          @view._itemMetadataProvider = (item) =>
            new Promise (resolve, reject) =>
              @resolves.push -> resolve('metadata-for-'+item.id)

          runs ->
            @completeQuery()
            expect(@view._pages[0].items).toEqual([])
            expect(@view._pages[0].metadata).toEqual({})
            expect(@view._emitter.emit).not.toHaveBeenCalled()

          waitsFor ->
            @resolves.length > 0

          runs ->
            for resolve,idx in @resolves
              resolve()

          waitsFor ->
            @view._emitter.emit.callCount > 0

          runs ->
            expect(@view._pages[0].items[0].metadata).toEqual('metadata-for-model-a')
            expect(@view._pages[0].items[1].metadata).toEqual('metadata-for-model-b')
            expect(@view._emitter.emit).toHaveBeenCalled()

