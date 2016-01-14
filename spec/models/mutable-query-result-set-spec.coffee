MutableQueryResultSet = require '../../src/flux/models/mutable-query-result-set'
QueryRange = require '../../src/flux/models/query-range'
_ = require 'underscore'

describe "MutableQueryResultSet", ->
  describe "clipToRange", ->
    it "should do nothing if the clipping range is infinite", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      beforeRange = set.range()
      set.clipToRange(QueryRange.infinite())
      afterRange = set.range()

      expect(beforeRange.isEqual(afterRange)).toBe(true)

    it "should correctly trim the result set 5-10 to the clipping range 2-9", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      expect(set.range().isEqual(new QueryRange(offset: 5, limit: 5))).toBe(true)
      set.clipToRange(new QueryRange(offset: 2, limit: 7))
      expect(set.range().isEqual(new QueryRange(offset: 5, limit: 4))).toBe(true)
      expect(set.ids()).toEqual(['A','B','C','D'])

    it "should correctly trim the result set 5-10 to the clipping range 5-10", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      set.clipToRange(new QueryRange(start: 5, end: 10))
      expect(set.range().isEqual(new QueryRange(start: 5, end: 10))).toBe(true)
      expect(set.ids()).toEqual(['A','B','C','D','E'])

    it "should correctly trim the result set 5-10 to the clipping range 6", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      set.clipToRange(new QueryRange(offset: 6, limit: 1))
      expect(set.range().isEqual(new QueryRange(offset: 6, limit: 1))).toBe(true)
      expect(set.ids()).toEqual(['B'])

    it "should correctly trim the result set 5-10 to the clipping range 100-200", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      set.clipToRange(new QueryRange(start: 100, end: 200))
      expect(set.range().isEqual(new QueryRange(start: 100, end: 100))).toBe(true)
      expect(set.ids()).toEqual([])

    it "should correctly trim the result set 5-10 to the clipping range 0-2", ->
      set = new MutableQueryResultSet(_ids: ['A','B','C','D','E'], _offset: 5)
      set.clipToRange(new QueryRange(offset: 0, limit: 2))
      expect(set.range().isEqual(new QueryRange(offset: 5, limit: 0))).toBe(true)
      expect(set.ids()).toEqual([])

    it "should trim the models cache to remove models no longer needed", ->
      set = new MutableQueryResultSet
        _ids: ['A','B','C','D','E'],
        _offset: 5
        _modelsHash: {
          'A-local': {id: 'A', clientId: 'A-local'},
          'A': {id: 'A', clientId: 'A-local'},
          'B-local': {id: 'B', clientId: 'B-local'},
          'B': {id: 'B', clientId: 'B-local'},
          'C-local': {id: 'C', clientId: 'C-local'},
          'C': {id: 'C', clientId: 'C-local'},
          'D-local': {id: 'D', clientId: 'D-local'},
          'D': {id: 'D', clientId: 'D-local'},
          'E-local': {id: 'E', clientId: 'E-local'},
          'E': {id: 'E', clientId: 'E-local'}
        }

      set.clipToRange(new QueryRange(start: 5, end: 8))
      expect(set._modelsHash).toEqual({
        'A-local': {id: 'A', clientId: 'A-local'},
        'A': {id: 'A', clientId: 'A-local'},
        'B-local': {id: 'B', clientId: 'B-local'},
        'B': {id: 'B', clientId: 'B-local'},
        'C-local': {id: 'C', clientId: 'C-local'},
        'C': {id: 'C', clientId: 'C-local'},
      })

  describe "addIdsInRange", ->
    describe "when the set is currently empty", ->
      it "should set the result set to the provided one", ->
        @set = new MutableQueryResultSet()
        @set.addIdsInRange(['B','C','D'], new QueryRange(start: 1, end: 4))
        expect(@set.ids()).toEqual(['B','C','D'])
        expect(@set.range().isEqual(new QueryRange(start: 1, end: 4))).toBe(true)

    describe "when the set has existing values", ->
      beforeEach ->
        @set = new MutableQueryResultSet
          _ids: ['A','B','C','D','E'],
          _offset: 5
          _modelsHash: {'A': {id: 'A'}, 'B': {id: 'B'}, 'C': {id: 'C'}, 'D': {id: 'D'}, 'E': {id: 'E'}}

      it "should throw an exception if the range provided doesn't intersect (trailing)", ->
        expect =>
          @set.addIdsInRange(['G', 'H', 'I'], new QueryRange(offset: 11, limit: 3))
        .toThrow()
        expect =>
          @set.addIdsInRange(['F', 'G', 'H'], new QueryRange(offset: 10, limit: 3))
        .not.toThrow()

      it "should throw an exception if the range provided doesn't intersect (leading)", ->
        expect =>
          @set.addIdsInRange(['0', '1', '2'], new QueryRange(offset: 1, limit: 3))
        .toThrow()
        expect =>
          @set.addIdsInRange(['0', '1', '2'], new QueryRange(offset: 2, limit: 3))
        .not.toThrow()

      it "should throw an exception if the range provided and the ids provided are different lengths", ->
        expect =>
          @set.addIdsInRange(['F', 'G', 'H'], new QueryRange(offset: 10, limit: 5))
        .toThrow()

      it "should correctly add ids (trailing) and update the offset", ->
        @set.addIdsInRange(['F', 'G', 'H'], new QueryRange(offset: 10, limit: 3))
        expect(@set.ids()).toEqual(['A','B','C','D','E','F','G','H'])
        expect(@set.range().offset).toEqual(5)

      it "should correctly add ids (leading) and update the offset", ->
        @set.addIdsInRange(['0', '1', '2'], new QueryRange(offset: 2, limit: 3))
        expect(@set.ids()).toEqual(['0', '1', '2', 'A','B','C','D','E'])
        expect(@set.range().offset).toEqual(2)

      it "should correctly add ids (middle) and update the offset", ->
        @set.addIdsInRange(['B-new', 'C-new', 'D-new'], new QueryRange(offset: 6, limit: 3))
        expect(@set.ids()).toEqual(['A', 'B-new', 'C-new', 'D-new','E'])
        expect(@set.range().offset).toEqual(5)

      it "should correctly add ids (middle+trailing) and update the offset", ->
        @set.addIdsInRange(['D-new', 'E-new', 'F-new'], new QueryRange(offset: 8, limit: 3))
        expect(@set.ids()).toEqual(['A', 'B', 'C', 'D-new','E-new', 'F-new'])
        expect(@set.range().offset).toEqual(5)
