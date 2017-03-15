/* eslint quote-props: 0 */
import MutableQueryResultSet from '../../src/flux/models/mutable-query-result-set';
import QueryRange from '../../src/flux/models/query-range';

describe("MutableQueryResultSet", function MutableQueryResultSetSpecs() {
  describe("clipToRange", () => {
    it("should do nothing if the clipping range is infinite", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      const beforeRange = set.range();
      set.clipToRange(QueryRange.infinite());
      const afterRange = set.range();

      expect(beforeRange.isEqual(afterRange)).toBe(true);
    });

    it("should correctly trim the result set 5-10 to the clipping range 2-9", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      expect(set.range().isEqual(new QueryRange({offset: 5, limit: 5}))).toBe(true);
      set.clipToRange(new QueryRange({offset: 2, limit: 7}));
      expect(set.range().isEqual(new QueryRange({offset: 5, limit: 4}))).toBe(true);
      expect(set.ids()).toEqual(['A', 'B', 'C', 'D']);
    });

    it("should correctly trim the result set 5-10 to the clipping range 5-10", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      set.clipToRange(new QueryRange({start: 5, end: 10}));
      expect(set.range().isEqual(new QueryRange({start: 5, end: 10}))).toBe(true);
      expect(set.ids()).toEqual(['A', 'B', 'C', 'D', 'E']);
    });

    it("should correctly trim the result set 5-10 to the clipping range 6", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      set.clipToRange(new QueryRange({offset: 6, limit: 1}));
      expect(set.range().isEqual(new QueryRange({offset: 6, limit: 1}))).toBe(true);
      expect(set.ids()).toEqual(['B']);
    });

    it("should correctly trim the result set 5-10 to the clipping range 100-200", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      set.clipToRange(new QueryRange({start: 100, end: 200}));
      expect(set.range().isEqual(new QueryRange({start: 100, end: 100}))).toBe(true);
      expect(set.ids()).toEqual([]);
    });

    it("should correctly trim the result set 5-10 to the clipping range 0-2", () => {
      const set = new MutableQueryResultSet({_ids: ['A', 'B', 'C', 'D', 'E'], _offset: 5});
      set.clipToRange(new QueryRange({offset: 0, limit: 2}));
      expect(set.range().isEqual(new QueryRange({offset: 5, limit: 0}))).toBe(true);
      expect(set.ids()).toEqual([]);
    });

    it("should trim the models cache to remove models no longer needed", () => {
      const set = new MutableQueryResultSet({
        _ids: ['A', 'B', 'C', 'D', 'E'],
        _offset: 5,
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
          'E': {id: 'E', clientId: 'E-local'},
        }});

      set.clipToRange(new QueryRange({start: 5, end: 8}));
      expect(set._modelsHash).toEqual({
        'A-local': {id: 'A', clientId: 'A-local'},
        'A': {id: 'A', clientId: 'A-local'},
        'B-local': {id: 'B', clientId: 'B-local'},
        'B': {id: 'B', clientId: 'B-local'},
        'C-local': {id: 'C', clientId: 'C-local'},
        'C': {id: 'C', clientId: 'C-local'},
      });
    });
  });

  describe("addIdsInRange", () => {
    describe("when the set is currently empty", () =>
      it("should set the result set to the provided one", () => {
        this.set = new MutableQueryResultSet();
        this.set.addIdsInRange(['B', 'C', 'D'], new QueryRange({start: 1, end: 4}));
        expect(this.set.ids()).toEqual(['B', 'C', 'D']);
        expect(this.set.range().isEqual(new QueryRange({start: 1, end: 4}))).toBe(true);
      })

    );

    describe("when the set has existing values", () => {
      beforeEach(() => {
        this.set = new MutableQueryResultSet({
          _ids: ['A', 'B', 'C', 'D', 'E'],
          _offset: 5,
          _modelsHash: {'A': {id: 'A'}, 'B': {id: 'B'}, 'C': {id: 'C'}, 'D': {id: 'D'}, 'E': {id: 'E'}},
        });
      });

      it("should throw an exception if the range provided doesn't intersect (trailing)", () => {
        expect(() => {
          this.set.addIdsInRange(['G', 'H', 'I'], new QueryRange({offset: 11, limit: 3}));
        }).toThrow();

        expect(() => {
          this.set.addIdsInRange(['F', 'G', 'H'], new QueryRange({offset: 10, limit: 3}));
        }).not.toThrow();
      });

      it("should throw an exception if the range provided doesn't intersect (leading)", () => {
        expect(() => {
          this.set.addIdsInRange(['0', '1', '2'], new QueryRange({offset: 1, limit: 3}));
        }).toThrow();

        expect(() => {
          this.set.addIdsInRange(['0', '1', '2'], new QueryRange({offset: 2, limit: 3}));
        }).not.toThrow();
      });

      it("should work if the IDs array is shorter than the result range they represent (addition)", () => {
        this.set.addIdsInRange(['F', 'G', 'H'], new QueryRange({offset: 10, limit: 5}));
        expect(this.set.ids()).toEqual(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']);
      });

      it("should work if the IDs array is shorter than the result range they represent (replacement)", () => {
        this.set.addIdsInRange(['A', 'B', 'C'], new QueryRange({offset: 5, limit: 5}));
        expect(this.set.ids()).toEqual(['A', 'B', 'C']);
      });

      it("should correctly add ids (trailing) and update the offset", () => {
        this.set.addIdsInRange(['F', 'G', 'H'], new QueryRange({offset: 10, limit: 3}));
        expect(this.set.ids()).toEqual(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']);
        expect(this.set.range().offset).toEqual(5);
      });

      it("should correctly add ids (leading) and update the offset", () => {
        this.set.addIdsInRange(['0', '1', '2'], new QueryRange({offset: 2, limit: 3}));
        expect(this.set.ids()).toEqual(['0', '1', '2', 'A', 'B', 'C', 'D', 'E']);
        expect(this.set.range().offset).toEqual(2);
      });

      it("should correctly add ids (middle) and update the offset", () => {
        this.set.addIdsInRange(['B-new', 'C-new', 'D-new'], new QueryRange({offset: 6, limit: 3}));
        expect(this.set.ids()).toEqual(['A', 'B-new', 'C-new', 'D-new', 'E']);
        expect(this.set.range().offset).toEqual(5);
      });

      it("should correctly add ids (middle+trailing) and update the offset", () => {
        this.set.addIdsInRange(['D-new', 'E-new', 'F-new'], new QueryRange({offset: 8, limit: 3}));
        expect(this.set.ids()).toEqual(['A', 'B', 'C', 'D-new', 'E-new', 'F-new']);
        expect(this.set.range().offset).toEqual(5);
      });
    });
  });

  describe('updateModel', () => {
    beforeEach(() => {
      this.mockModel = (clientId, serverId) => {
        return {
          id: serverId || clientId,
          clientId: clientId,
          serverId: serverId,
          constructor: {
            attributes: [],
          },
        }
      }
    })

    /*
      Previously, after creating a new folder, the UI would indicate that the new
      folder had children, even though it didn't. This was caused by duplicate models
      in our MutableQueryResultSet for the user's categories. Basically, we would
      sync the server version of the folder before the SyncbackTask for the new
      folder returned its serverId. Without the serverId, the synced version of
      the folder couldn't yet be tied to the optimistic folder, so a second row was
      created in the database. This second row is removed when the syncbackTask
      does return the serverId, because we persist the optimistic folder with a
      'REPLACE INTO' query. (This deletes other rows with the same id.) However,
      since this was done inside a 'persist' change with the serverId and no
      'unpersist' was ever recorded for the clientId, our MutableQueryResultSet
      never removed the clientId model. We now detect this case within
      updateModel and remove the clientId when necessary.
    */
    describe('when the model is an optimistic copy receiving its serverId', () => {
      it('removes the clientId if both the clientId and serverId are listed', () => {
        const set = new MutableQueryResultSet({
          _ids: ['clientId1', 'serverId1', 'serverId2', 'serverId3'],
          _modelsHash: {
            'clientId1': this.mockModel('clientId1'),
            'serverId2': this.mockModel('clientId2', 'serverId2'),
            'serverId3': this.mockModel('clientId3', 'serverId3'),
            'serverId1': this.mockModel('clientId4', 'serverId1'),
          },
        });

        set.updateModel(this.mockModel('clientId1', 'serverId1'))
        expect(set.ids().includes('clientId1')).toEqual(false)
      })

      it('does not remove the clientId if the serverId is not listed', () => {
        const set = new MutableQueryResultSet({
          _ids: ['clientId1', 'serverId2', 'serverId3'],
          _modelsHash: {
            'clientId1': this.mockModel('clientId1'),
            'serverId2': this.mockModel('clientId2', 'serverId2'),
            'serverId3': this.mockModel('clientId3', 'serverId3'),
          },
        });

        set.updateModel(this.mockModel('clientId1', 'serverId1'))
        expect(set.ids().includes('clientId1')).toEqual(true)
      })
    })
  });
});
