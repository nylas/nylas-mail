import {Table} from 'nylas-component-kit'
import {MAX_ROWS} from './mail-merge-constants'

const {TableDataSource} = Table


export function toJSON({tableDataSource}) {
  return {
    tableDataSource: tableDataSource.toJSON(),
  }
}

export function fromJSON({tableDataSource}) {
  return {
    tableDataSource: new TableDataSource(tableDataSource),
  }
}

export function initialState(savedState) {
  if (savedState && savedState.tableDataSource instanceof TableDataSource) {
    if (savedState.failedDraftRowIdxs) {
      const failedRowIdxs = new Set(savedState.failedDraftRowIdxs)
      const dataSource = (
        savedState.tableDataSource
        .filterRows((row, idx) => failedRowIdxs.has(idx))
      )
      return {
        tableDataSource: dataSource,
      }
    }
    return {
      tableDataSource: savedState.tableDataSource,
    }
  }
  return {
    tableDataSource: new TableDataSource({
      columns: ['email'],
      rows: [
        [null],
      ],
    }),
  }
}

export function clearTableData({tableDataSource}) {
  return {
    tableDataSource: tableDataSource.clear(),
  }
}

export function loadTableData({tableDataSource}, {newTableData}) {
  const newRows = newTableData.rows
  const newCols = newTableData.columns
  if (newRows.length === 0 || newCols.length === 0) {
    return initialState()
  }
  return {
    tableDataSource: new TableDataSource(newTableData),
  }
}

export function addColumn({tableDataSource}) {
  return {
    tableDataSource: tableDataSource.addColumn(),
  }
}

export function removeLastColumn({tableDataSource}) {
  return {
    tableDataSource: tableDataSource.removeLastColumn(),
  }
}

export function addRow({tableDataSource}, {maxRows = MAX_ROWS} = {}) {
  const rows = tableDataSource.rows()
  if (rows.length === maxRows) {
    return {tableDataSource}
  }

  return {
    tableDataSource: tableDataSource.addRow(),
  }
}

export function removeRow({tableDataSource}) {
  return {
    tableDataSource: tableDataSource.removeRow(),
  }
}

export function updateCell({tableDataSource}, {rowIdx, colIdx, isHeader, value}) {
  return {
    tableDataSource: tableDataSource.updateCell({rowIdx, colIdx, isHeader, value}),
  }
}
