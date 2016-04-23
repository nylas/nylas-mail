
function updateColumns({columns}, {colIdx, value}) {
  const newColumns = columns.slice(0)
  newColumns[colIdx] = value
  return newColumns
}

function updateRows({rows}, {row, col, value}) {
  const newRows = rows.slice(0)
  newRows[row][col] = value
  return newRows
}

export function initialState(savedData) {
  if (savedData && savedData.tableData) {
    return {
      tableData: savedData.tableData,
      selection: {
        row: 1,
        col: 0,
        key: null,
      },
    }
  }
  return {
    tableData: {
      columns: ['email'],
      rows: [
        ['email'],
        [null],
      ],
    },
    selection: {
      row: 1,
      col: 0,
      key: 'Enter',
    },
  }
}

export function addColumn({selection, tableData}) {
  const {columns, rows} = tableData
  const newColumns = columns.concat([''])
  return {
    tableData: {
      ...tableData,
      rows: rows.map(row => row.concat(null)),
      columns: newColumns,
    },
    selection: {
      ...selection,
      row: 0,
      col: newColumns.length - 1,
      key: 'Enter',
    },
  }
}

export function removeColumn({selection, tableData}) {
  const {rows, columns} = tableData
  const newSelection = {...selection, key: null}
  if (newSelection.col === columns.length - 1) {
    newSelection.col--
  }
  return {
    tableData: {
      ...tableData,
      rows: rows.map(row => row.slice(0, columns.length - 1)),
      columns: columns.slice(0, columns.length - 1),
    },
    selection: newSelection,
  }
}

export function addRow({selection, tableData}) {
  const {rows, columns} = tableData
  const newRows = rows.concat([columns.map(() => null)])
  return {
    tableData: {
      ...tableData,
      rows: newRows,
    },
    selection: {
      ...selection,
      row: newRows.length - 1,
      key: 'Enter',
    },
  }
}

export function removeRow({selection, tableData}) {
  const {rows} = tableData
  const newSelection = {...selection, key: null}
  if (newSelection.row === rows.length - 1) {
    newSelection.row--
  }
  return {
    tableData: {
      ...tableData,
      rows: rows.slice(0, rows.length - 1),
    },
    selection: newSelection,
  }
}

export function updateCell({tableData, selection}, {row, col, value}) {
  const newSelection = {...selection, key: null}
  if (row === 0) {
    return {
      tableData: {
        ...tableData,
        rows: updateRows(tableData, {row, col, value}),
        columns: updateColumns(tableData, {col, value}),
      },
      selection: newSelection,
    }
  }
  return {
    tableData: {
      ...tableData,
      rows: updateRows(tableData, {row, col, value}),
    },
    selection: newSelection,
  }
}

export function setSelection({selection}, newSelection) {
  return {
    selection: {...newSelection},
  }
}

export function shiftSelection({tableData, selection}, deltas) {
  const rowLen = tableData.rows.length
  const colLen = tableData.columns.length
  const shift = (len, idx, delta = 0) => Math.min(len - 1, Math.max(0, idx + (delta)))

  return {
    selection: {
      ...selection,
      row: shift(rowLen, selection.row, deltas.row),
      col: shift(colLen, selection.col, deltas.col),
      key: deltas.key,
    },
  }
}
