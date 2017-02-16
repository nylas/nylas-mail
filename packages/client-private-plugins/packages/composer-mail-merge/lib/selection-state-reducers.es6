import _ from 'underscore'
import {MAX_ROWS} from './mail-merge-constants'


export function initialState(savedState) {
  if (savedState && savedState.tableDataSource) {
    return {
      selection: {
        rowIdx: 0,
        colIdx: 0,
        key: null,
      },
    }
  }
  return {
    selection: {
      rowIdx: 0,
      colIdx: 0,
      key: 'Enter',
    },
  }
}

export function clearTableData() {
  return {
    selection: {
      rowIdx: 0,
      colIdx: 0,
      key: null,
    },
  }
}

export function loadTableData() {
  return {
    selection: {
      rowIdx: 0,
      colIdx: 0,
      key: null,
    },
  }
}

export function addColumn({selection, tableDataSource}) {
  const columns = tableDataSource.columns()
  return {
    selection: {
      ...selection,
      rowIdx: null,
      colIdx: columns.length,
      key: 'Enter',
    },
  }
}

export function removeLastColumn({selection, tableDataSource}) {
  const columns = tableDataSource.columns()
  const nextSelection = {...selection, key: null}
  if (nextSelection.colIdx === columns.length - 1) {
    nextSelection.colIdx--
  }

  return {selection: nextSelection}
}

export function addRow({selection, tableDataSource}, {maxRows = MAX_ROWS} = {}) {
  const rows = tableDataSource.rows()
  if (rows.length === maxRows) {
    return {selection}
  }

  return {
    selection: {
      ...selection,
      rowIdx: rows.length,
      key: 'Enter',
    },
  }
}

export function removeRow({selection, tableDataSource}) {
  const rows = tableDataSource.rows()
  const nextSelection = {...selection, key: null}
  if (nextSelection.rowIdx === rows.length - 1) {
    nextSelection.rowIdx--
  }

  return {selection: nextSelection}
}

export function updateCell({selection}) {
  return {
    selection: {...selection, key: null},
  }
}

export function setSelection({selection}, nextSelection) {
  if (_.isEqual(selection, nextSelection)) {
    return {selection}
  }
  return {
    selection: {...nextSelection},
  }
}

function shift(len, idx, delta = 0) {
  const idxVal = idx != null ? idx : -1
  return Math.min(len - 1, Math.max(0, idxVal + delta))
}

export function shiftSelection({tableDataSource, selection}, deltas) {
  const rowLen = tableDataSource.rows().length
  const colLen = tableDataSource.columns().length

  const nextSelection = {
    rowIdx: shift(rowLen, selection.rowIdx, deltas.row),
    colIdx: shift(colLen, selection.colIdx, deltas.col),
    key: deltas.key,
  }

  return setSelection({selection}, nextSelection)
}
