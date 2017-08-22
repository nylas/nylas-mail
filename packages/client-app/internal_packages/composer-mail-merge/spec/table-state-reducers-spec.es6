import {
  initialState,
  fromJSON,
  toJSON,
  clearTableData,
  loadTableData,
  addColumn,
  removeLastColumn,
  addRow,
  removeRow,
  updateCell,
} from '../lib/table-state-reducers'
import {testData, testDataSource} from './fixtures'


describe('TableStateReducers', function describeBlock() {
  describe('initialState', () => {
    it('returns correct initial state when there is saved state', () => {
      const savedState = {tableDataSource: testDataSource}
      expect(initialState(savedState)).toEqual(savedState)
    });

    it('keeps only rowIdxs that failed if failedRowIdxs present in saved state', () => {
      const savedState = {tableDataSource: testDataSource, failedDraftRowIdxs: [1]}
      const {tableDataSource} = initialState(savedState)
      expect(tableDataSource.rows()).toEqual([testDataSource.rowAt(1)])
    });
  });

  describe('fromJSON', () => {
    it('returns correct data source from json table data', () => {
      const {tableDataSource} = fromJSON({tableDataSource: testData})
      expect(tableDataSource.toJSON()).toEqual(testData)
    });
  });

  describe('toJSON', () => {
    it('returns correct json object from data source', () => {
      const {tableDataSource} = toJSON({tableDataSource: testDataSource})
      expect(tableDataSource).toEqual(testData)
    });
  });

  describe('clearTableData', () => {
    it('clears all data correcltly', () => {
      const {tableDataSource} = clearTableData({tableDataSource: testDataSource})
      expect(tableDataSource.toJSON()).toEqual({
        columns: [],
        rows: [[]],
      })
    });
  });

  describe('loadTableData', () => {
    it('loads table data correctly', () => {
      const newTableData = {
        columns: ['my-col'],
        rows: [['my-val']],
      }
      const {tableDataSource} = loadTableData({tableDataSource: testDataSource}, {newTableData})
      expect(tableDataSource.toJSON()).toEqual(newTableData)
    });

    it('returns initial state if new table data is empty', () => {
      const newTableData = {
        columns: [],
        rows: [[]],
      }
      const {tableDataSource} = loadTableData({tableDataSource: testDataSource}, {newTableData})
      expect(tableDataSource.toJSON()).toEqual(initialState().tableDataSource.toJSON())
    });
  });

  describe('addColumn', () => {
    it('pushes a new column to the data source\'s columns', () => {
      const {tableDataSource} = addColumn({tableDataSource: testDataSource})
      expect(tableDataSource.columns()).toEqual(['name', 'email', null])
    });

    it('pushes a new column to every row', () => {
      const {tableDataSource} = addColumn({tableDataSource: testDataSource})
      expect(tableDataSource.rows()).toEqual([
        ['donald', 'donald@nylas.com', null],
        ['hilary', 'hilary@nylas.com', null],
      ])
    });
  });

  describe('removeLastColumn', () => {
    it('removes last column from the data source\'s columns', () => {
      const {tableDataSource} = removeLastColumn({tableDataSource: testDataSource})
      expect(tableDataSource.columns()).toEqual(['name'])
    });

    it('removes last column from every row', () => {
      const {tableDataSource} = removeLastColumn({tableDataSource: testDataSource})
      expect(tableDataSource.rows()).toEqual([['donald'], ['hilary']])
    });
  });

  describe('addRow', () => {
    it('does nothing if MAX_ROWS reached', () => {
      const {tableDataSource} = addRow({tableDataSource: testDataSource}, {maxRows: 2})
      expect(tableDataSource).toBe(testDataSource)
    });

    it('pushes an empty row with correct number of columns', () => {
      const {tableDataSource} = addRow({tableDataSource: testDataSource}, {maxRows: 3})
      expect(tableDataSource.rows()).toEqual([
        ['donald', 'donald@nylas.com'],
        ['hilary', 'hilary@nylas.com'],
        [null, null],
      ])
    });
  });

  describe('removeRow', () => {
    it('removes last row', () => {
      const {tableDataSource} = removeRow({tableDataSource: testDataSource})
      expect(tableDataSource.rows()).toEqual([['donald', 'donald@nylas.com']])
    });
  });

  describe('updateCell', () => {
    it('updates cell value correctly when updating a cell that is /not/ a header', () => {
      const {tableDataSource} = updateCell({tableDataSource: testDataSource}, {
        rowIdx: 0, colIdx: 0, isHeader: false, value: 'new-val',
      })
      expect(tableDataSource.rows()).toEqual([
        ['new-val', 'donald@nylas.com'],
        ['hilary', 'hilary@nylas.com'],
      ])
    });

    it('updates cell value correctly when updating a cell that /is/ a header', () => {
      const {tableDataSource} = updateCell({tableDataSource: testDataSource}, {
        rowIdx: null, colIdx: 0, isHeader: true, value: 'new-val',
      })
      expect(tableDataSource.columns()).toEqual(['new-val', 'email'])
    });
  });
});
