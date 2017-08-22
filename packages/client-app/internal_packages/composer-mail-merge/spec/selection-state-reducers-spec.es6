import {
  clearTableData,
  loadTableData,
  addColumn,
  removeLastColumn,
  addRow,
  removeRow,
  updateCell,
  setSelection,
  shiftSelection,
} from '../lib/selection-state-reducers'
import {testState, testSelection} from './fixtures'


describe('SelectionStateReducers', function describeBlock() {
  describe('clearTableData', () => {
    it('sets selection correctly', () => {
      const {selection} = clearTableData()
      expect(selection).toEqual({
        rowIdx: 0,
        colIdx: 0,
        key: null,
      })
    });
  });

  describe('loadTableData', () => {
    it('sets selection correctly', () => {
      const {selection} = loadTableData()
      expect(selection).toEqual({
        rowIdx: 0,
        colIdx: 0,
        key: null,
      })
    });
  });

  describe('addColumn', () => {
    it('sets selection to the header and last column', () => {
      const {selection} = addColumn(testState)
      expect(selection).toEqual({rowIdx: null, colIdx: 2, key: 'Enter'})
    });
  });

  describe('removeLastColumn', () => {
    it('only sets key to null if selection is not in last column', () => {
      const {selection} = removeLastColumn(testState)
      expect(selection).toEqual({...testSelection, key: null})
    });

    it('decreases col selection by 1 if selection is currently in last column', () => {
      const {selection} = removeLastColumn({...testState, selection: {rowIdx: 1, colIdx: 1, key: 'Enter'}})
      expect(selection).toEqual({rowIdx: 1, colIdx: 0, key: null})
    });
  });

  describe('addRow', () => {
    it('does nothing if MAX_ROWS reached', () => {
      const {selection} = addRow(testState, {maxRows: 2})
      expect(selection).toBe(testSelection)
    });

    it('sets selection to last row', () => {
      const {selection} = addRow(testState, {maxRows: 3})
      expect(selection).toEqual({rowIdx: 2, colIdx: 0, key: 'Enter'})
    });
  });

  describe('removeRow', () => {
    it('only sets key to null if selection is not in last row', () => {
      const {selection} = removeRow(testState)
      expect(selection).toEqual({...testSelection, rowIdx: 0, key: null})
    });

    it('decreases row selection by 1 if selection is currently in last row', () => {
      const {selection} = removeRow({...testState, selection: {rowIdx: 1, colIdx: 1, key: 'Enter'}})
      expect(selection).toEqual({rowIdx: 0, colIdx: 1, key: null})
    });
  });

  describe('updateCell', () => {
    it('sets selection key to null (wont make input focus)', () => {
      const {selection} = updateCell(testState)
      expect(selection.key).toBe(null)
    });
  });

  describe('setSelection', () => {
    it('sets the selection to the given selection if selection has changed', () => {
      const {selection} = setSelection(testState, {rowIdx: 1, colIdx: 1, key: null})
      expect(selection).toEqual({rowIdx: 1, colIdx: 1, key: null})
    });

    it('returns same selection otherwise', () => {
      const {selection} = setSelection(testState, {...testSelection})
      expect(selection).toBe(testSelection)
    });
  });

  describe('shiftSelection', () => {
    it('sets the given key', () => {
      const {selection} = shiftSelection(testState, {row: 0, col: 0, key: null})
      expect(selection.key).toBe(null)
    });

    it('shifts row selection correctly when rowIdx is null (header)', () => {
      let nextSelection = shiftSelection({
        ...testState,
        selection: {rowIdx: null, col: 0},
      }, {row: 1}).selection
      expect(nextSelection.rowIdx).toBe(0)

      nextSelection = shiftSelection({
        ...testState,
        selection: {rowIdx: null, col: 0},
      }, {row: 2}).selection
      expect(nextSelection.rowIdx).toBe(1)

      nextSelection = shiftSelection({
        ...testState,
        selection: {rowIdx: null, col: 0},
      }, {row: -1}).selection
      expect(nextSelection.rowIdx).toBe(0)
    });

    it('shifts row selection by correct value', () => {
      let nextState = shiftSelection(
        testState,
        {row: -1}
      )
      expect(nextState.selection.rowIdx).toBe(0)

      nextState = shiftSelection(
        {...testState, selection: {rowIdx: 0, colIdx: 0, key: 'Enter'}},
        {row: 1}
      )
      expect(nextState.selection.rowIdx).toBe(1)
    });

    it('does not shift row selection when at the edges', () => {
      let nextState = shiftSelection(
        testState,
        {row: 2}
      )
      expect(nextState.selection.rowIdx).toBe(1)

      nextState = shiftSelection(
        {...testState, selection: {rowIdx: 0, colIdx: 0, key: 'Enter'}},
        {row: -2}
      )
      expect(nextState.selection.rowIdx).toBe(0)
    });

    it('shifts col selection by correct value', () => {
      let nextState = shiftSelection(
        testState,
        {col: 1}
      )
      expect(nextState.selection.colIdx).toBe(1)

      nextState = shiftSelection(
        {...testState, selection: {rowIdx: 0, colIdx: 1, key: 'Enter'}},
        {col: -1}
      )
      expect(nextState.selection.colIdx).toBe(0)
    });

    it('does not shift col selection when at the edges', () => {
      let nextState = shiftSelection(
        testState,
        {col: -2}
      )
      expect(nextState.selection.colIdx).toBe(0)

      nextState = shiftSelection(
        {...testState, selection: {rowIdx: 0, colIdx: 1, key: 'Enter'}},
        {col: 2}
      )
      expect(nextState.selection.colIdx).toBe(1)
    });
  });
});
