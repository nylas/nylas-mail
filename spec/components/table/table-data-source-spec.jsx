import {
  testData,
  testDataSource,
  testDataSourceEmpty,
  testDataSourceUneven,
} from '../../fixtures/table-data'


describe('TableDataSource', function describeBlock() {
  describe('colAt', () => {
    it('returns the correct value for column', () => {
      expect(testDataSource.colAt(1)).toEqual('col2')
    });

    it('returns null if col does not exist', () => {
      expect(testDataSource.colAt(3)).toBe(null)
    });
  });

  describe('rowAt', () => {
    it('returns correct row', () => {
      expect(testDataSource.rowAt(1)).toEqual([4, 5, 6])
    });

    it('returns columns if rowIdx is null', () => {
      expect(testDataSource.rowAt(null)).toEqual(['col1', 'col2', 'col3'])
    });

    it('returns null if row does not exist', () => {
      expect(testDataSource.rowAt(3)).toBe(null)
    });
  });

  describe('cellAt', () => {
    it('returns correct cell', () => {
      expect(testDataSource.cellAt({rowIdx: 1, colIdx: 1})).toEqual(5)
    });

    it('returns correct col if rowIdx is null', () => {
      expect(testDataSource.cellAt({rowIdx: null, colIdx: 1})).toEqual('col2')
    });

    it('returns null if cell does not exist', () => {
      expect(testDataSource.cellAt({rowIdx: 3, colIdx: 1})).toBe(null)
      expect(testDataSource.cellAt({rowIdx: 1, colIdx: 3})).toBe(null)
    });
  });

  describe('isEmpty', () => {
    it('throws if no args passed', () => {
      expect(() => testDataSource.isEmpty()).toThrow()
    });

    it('throws if row does not exist', () => {
      expect(() => testDataSource.isEmpty({rowIdx: 100})).toThrow()
    });

    it('throws if col does not exist', () => {
      expect(() => testDataSource.isEmpty({colIdx: 100})).toThrow()
    });

    it('returns correct value when checking cell', () => {
      expect(testDataSourceEmpty.isEmpty({rowIdx: 2, colIdx: 1})).toBe(true)
      expect(testDataSourceEmpty.isEmpty({rowIdx: 3, colIdx: 1})).toBe(true)
      expect(testDataSourceEmpty.isEmpty({rowIdx: 0, colIdx: 0})).toBe(false)
    });

    it('returns correct value when checking col', () => {
      expect(testDataSourceEmpty.isEmpty({colIdx: 2})).toBe(true)
      expect(testDataSourceEmpty.isEmpty({colIdx: 0})).toBe(false)
    });

    it('returns correct value when checking row', () => {
      expect(testDataSourceEmpty.isEmpty({rowIdx: 2})).toBe(true)
      expect(testDataSourceEmpty.isEmpty({rowIdx: 3})).toBe(true)
      expect(testDataSourceEmpty.isEmpty({rowIdx: 1})).toBe(false)
    });
  });

  describe('rows', () => {
    it('returns all rows', () => {
      expect(testDataSource.rows()).toBe(testData.rows)
    });
  });

  describe('columns', () => {
    it('returns all columns', () => {
      expect(testDataSource.columns()).toBe(testData.columns)
    });
  });

  describe('addColumn', () => {
    it('pushes a new column to the data source\'s columns', () => {
      const res = testDataSource.addColumn()
      expect(res.columns()).toEqual(['col1', 'col2', 'col3', null])
    });

    it('pushes a new column to every row', () => {
      const res = testDataSource.addColumn()
      expect(res.rows()).toEqual([
        [1, 2, 3, null],
        [4, 5, 6, null],
        [7, 8, 9, null],
      ])
    });
  });

  describe('removeLastColumn', () => {
    it('removes last column from the data source\'s columns', () => {
      const res = testDataSource.removeLastColumn()
      expect(res.columns()).toEqual(['col1', 'col2'])
    });

    it('removes last column from every row', () => {
      const res = testDataSource.removeLastColumn()
      expect(res.rows()).toEqual([
        [1, 2],
        [4, 5],
        [7, 8],
      ])
    });

    it('removes the last column only from every row with that column', () => {
      const res = testDataSourceUneven.removeLastColumn()
      expect(res.rows()).toEqual([
        [1, 2],
        [4, 5],
        [7, 8],
      ])
    })
  });

  describe('addRow', () => {
    it('pushes an empty row with correct number of columns', () => {
      const res = testDataSource.addRow()
      expect(res.rows()).toEqual([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [null, null, null],
      ])
    });
  });

  describe('removeRow', () => {
    it('removes last row', () => {
      const res = testDataSource.removeRow()
      expect(res.rows()).toEqual([
        [1, 2, 3],
        [4, 5, 6],
      ])
    });
  });

  describe('updateCell', () => {
    it('updates cell value correctly when updating a cell that is /not/ a header', () => {
      const res = testDataSource.updateCell({
        rowIdx: 0, colIdx: 0, isHeader: false, value: 'new-val',
      })
      expect(res.columns()).toBe(testDataSource.columns())
      expect(res.rows()).toEqual([
        ['new-val', 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ])

      // If a row doesn't change, it should be the same row
      testDataSource.rows().slice(1).forEach((row, rowIdx) => expect(row).toBe(testDataSource.rowAt(rowIdx + 1)))
    });

    it('updates cell value correctly when updating a cell that /is/ a header', () => {
      const res = testDataSource.updateCell({
        rowIdx: null, colIdx: 0, isHeader: true, value: 'new-val',
      })
      expect(res.columns()).toEqual(['new-val', 'col2', 'col3'])
      expect(res.rows()).toBe(testDataSource.rows())

      // If a row doesn't change, it should be the same row
      testDataSource.rows().forEach((row, rowIdx) => expect(row).toBe(testDataSource.rowAt(rowIdx)))
    });
  });

  describe('clear', () => {
    it('clears all data correcltly', () => {
      const res = testDataSource.clear()
      expect(res.toJSON()).toEqual({
        columns: [],
        rows: [[]],
      })
    });
  });

  describe('toJSON', () => {
    it('returns correct json object from data source', () => {
      const res = testDataSource.toJSON()
      expect(res).toEqual(testData)
    });
  });
});
