import {Table} from 'nylas-component-kit'

export const testData = {
  columns: ['col1', 'col2', 'col3'],
  rows: [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
  ],
}

class TestSource extends Table.TableDataSource {
  setRows(rows) {
    const data = {
      rows: [...rows],
      columns: this.columns(),
    }
    return new TestSource(data)
  }
}

export const testDataSource = new TestSource(testData)

export const selection = {colIdx: 0, rowIdx: 0, key: null}

export const cellProps = {tableDataSource: testDataSource, selection, colIdx: 0, rowIdx: 0, onSetSelection: () => {}, onCellEdited: () => {}}

export const rowProps = {tableDataSource: testDataSource, selection, rowIdx: 0}

export const tableProps = {tableDataSource: testDataSource, selection, onSetSelection: () => {}, onShiftSelection: () => {}, onCellEdited: () => {}}
