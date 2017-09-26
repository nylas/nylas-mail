import QueryRange from '../../src/flux/models/query-range';

describe('QueryRange', function QueryRangeSpecs() {
  describe('@infinite', () =>
    it('should return a query range with a null limit and offset', () => {
      const infinite = QueryRange.infinite();
      expect(infinite.limit).toBe(null);
      expect(infinite.offset).toBe(null);
    }));

  describe('@rangesBySubtracting', () => {
    it('should throw an exception if either range is infinite', () => {
      const infinite = QueryRange.infinite();

      expect(() =>
        QueryRange.rangesBySubtracting(infinite, new QueryRange({ offset: 0, limit: 10 }))
      ).toThrow();

      expect(() =>
        QueryRange.rangesBySubtracting(new QueryRange({ offset: 0, limit: 10 }), infinite)
      ).toThrow();
    });

    it('should return one or more ranges created by punching the provided range', () => {
      const test = ({ a, b, result }) =>
        expect(QueryRange.rangesBySubtracting(a, b)).toEqual(result);
      test({
        a: new QueryRange({ offset: 0, limit: 10 }),
        b: new QueryRange({ offset: 3, limit: 3 }),
        result: [new QueryRange({ offset: 0, limit: 3 }), new QueryRange({ offset: 6, limit: 4 })],
      });

      test({
        a: new QueryRange({ offset: 0, limit: 10 }),
        b: new QueryRange({ offset: 3, limit: 10 }),
        result: [new QueryRange({ offset: 0, limit: 3 })],
      });

      test({
        a: new QueryRange({ offset: 0, limit: 10 }),
        b: new QueryRange({ offset: 0, limit: 10 }),
        result: [],
      });

      test({
        a: new QueryRange({ offset: 5, limit: 10 }),
        b: new QueryRange({ offset: 0, limit: 4 }),
        result: [new QueryRange({ offset: 5, limit: 10 })],
      });

      test({
        a: new QueryRange({ offset: 5, limit: 10 }),
        b: new QueryRange({ offset: 0, limit: 8 }),
        result: [new QueryRange({ offset: 8, limit: 7 })],
      });
    });
  });

  describe('isInfinite', () =>
    it('should return true for an infinite range, false otherwise', () => {
      const infinite = QueryRange.infinite();
      expect(infinite.isInfinite()).toBe(true);
      expect(new QueryRange({ offset: 0, limit: 4 }).isInfinite()).toBe(false);
    }));

  describe('start', () =>
    it('should be an alias for offset', () =>
      expect(new QueryRange({ offset: 3, limit: 4 }).start).toBe(3)));

  describe('end', () =>
    it('should be offset + limit', () =>
      expect(new QueryRange({ offset: 3, limit: 4 }).end).toBe(7)));

  describe('isContiguousWith', () => {
    it('should return true if either range is infinite', () => {
      const a = new QueryRange({ offset: 3, limit: 4 });
      expect(a.isContiguousWith(QueryRange.infinite())).toBe(true);
      expect(QueryRange.infinite().isContiguousWith(a)).toBe(true);
    });

    it('should return true if the ranges intersect or touch, false otherwise', () => {
      const a = new QueryRange({ offset: 3, limit: 4 });
      const b = new QueryRange({ offset: 0, limit: 2 });
      const c = new QueryRange({ offset: 0, limit: 3 });
      const d = new QueryRange({ offset: 7, limit: 10 });
      const e = new QueryRange({ offset: 8, limit: 10 });

      // True

      expect(a.isContiguousWith(d)).toBe(true);
      expect(d.isContiguousWith(a)).toBe(true);

      expect(a.isContiguousWith(c)).toBe(true);
      expect(c.isContiguousWith(a)).toBe(true);

      // False

      expect(a.isContiguousWith(b)).toBe(false);
      expect(b.isContiguousWith(a)).toBe(false);

      expect(a.isContiguousWith(e)).toBe(false);
      expect(e.isContiguousWith(a)).toBe(false);

      expect(b.isContiguousWith(e)).toBe(false);
      expect(e.isContiguousWith(b)).toBe(false);
    });
  });
});
