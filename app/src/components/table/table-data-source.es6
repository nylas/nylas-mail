/**
 * Base class that defines an interface to access table data.
 * All methods that modify data are immutable, which means a new instance of
 * `TableDataSource` is returned with the new data.
 *
 * This class can be used as is for a default implementation of table
 * data operations, but is meant be extended for different implementations
 *
 * @class TableDataSource
 */
export default class TableDataSource {
  /**
   * Takes an Object of the form:
   *
   * ```
   * const tableData = {
   *   columns: ['col1', 'col2'],
   *   rows: [
   *     [1, 2],
   *     [3, 4],
   *     [5, null]
   *   ],
   * }
   *
   * @param {object} tableData
   * @param {array} tableData.columns - Array of columns
   * @param {array} tableData.rows - Array of rows
   * @method constructor
   */
  constructor(tableData) {
    this._tableData = tableData || {
      columns: [],
      rows: [[]],
    };
  }

  /**
   * ```
   * source.colAt(2)
   * ```
   *
   * @param {number} colIdx - Index of column name to retrieve
   * @return {any} - value for column at given index or null if does not exist
   * @method colAt
   */
  colAt(colIdx) {
    const col = this._tableData.columns[colIdx];
    return col != null ? col : null;
  }

  /**
   * Returns the row at the given index. If rowIdx is null or undefined, returns
   * the array of columns.
   *
   * If the row at the given rowIdx does not exists, returns null
   *
   * ```
   * source.rowAt(2)
   * ```
   *
   * @param {number} rowIdx - Index of row to retrieve
   * @return {array} - row for given index or null if does not exist
   * @method rowAt
   */
  rowAt(rowIdx) {
    if (rowIdx == null) {
      return this.columns();
    }
    return this._tableData.rows[rowIdx] || null;
  }

  /**
   * Returns the cell data at the given indixes. If rowIdx is null or undefined,
   * returns the value for the column at colIdx
   *
   * If the cell at the given indices does not exists, returns null
   *
   * ```
   * source.cellAt({rowIdx: 1, colIdx: 2})
   * ```
   *
   * @param {object} arg
   * @param {number} arg.rowIdx - Row index of cell
   * @param {number} arg.colIdx - Col index of cell
   * @return {any} - value for cell at given indices or null if it does not exist
   * @method cellAt
   */
  cellAt({ rowIdx, colIdx } = {}) {
    if (rowIdx == null) {
      return this.colAt(colIdx);
    }
    const row = this.rowAt(rowIdx);
    const cell = row ? row[colIdx] : null;
    return cell != null ? cell : null;
  }

  /**
   * Returns true if the given cell, column, or row is empty
   *
   * ```
   * source.isEmpty({rowIdx: 1}) // true if row 1 is empty
   * ```
   *
   * @param {object} arg
   * @param {number} arg.rowIdx - Row index of cell
   * @param {number} arg.colIdx - Col index of cell
   * @return {any} - value for cell at given indices or null if it does not exist
   * @method cellAt
   */
  isEmpty({ rowIdx, colIdx } = {}) {
    if (rowIdx == null && colIdx == null) {
      throw new Error('TableDataSource::isEmpty - Must provide rowIdx and/or colIdx');
    }
    if (rowIdx == null) {
      const col = this.colAt(colIdx);
      if (col == null) {
        throw new Error('TableDataSource::isEmpty - Must provide a valid colIdx');
      }
    }
    const row = this.rowAt(rowIdx);
    if (!row) {
      throw new Error('TableDataSource::isEmpty - Must provide a valid rowIdx');
    }
    if (colIdx == null) {
      return row.every(el => !el);
    }
    return !this.cellAt({ rowIdx, colIdx });
  }

  /**
   * ```
   * source.rows()
   * ```
   *
   * @return {array} - all table rows
   * @method rows
   */
  rows() {
    return this._tableData.rows;
  }

  /**
   * ```
   * source.columns()
   * ```
   *
   * @return {array} - table columns (headers)
   * @method rows
   */
  columns() {
    return this._tableData.columns;
  }

  /**
   * Adds column
   *
   * @return {TableDataSource} - updated data source instance
   * @method addColumn
   */
  addColumn(name = null) {
    const rows = this.rows();
    const columns = this.columns();
    return new TableDataSource({
      ...this._tableData,
      rows: rows.map(row => row.concat(null)),
      columns: columns.concat([name]),
    });
  }

  /**
   * Removes last column and all of its data.
   *
   * @return {TableDataSource} - updated data source instance
   * @method removeLastColumn
   */
  removeLastColumn() {
    const nextNumColumns = this.columns().length - 1;
    const nextRows = this.rows().map(row => row.slice(0, nextNumColumns));
    const nextColumns = this.columns().slice(0, nextNumColumns);
    return new TableDataSource({
      ...this._tableData,
      rows: nextRows,
      columns: nextColumns,
    });
  }

  /**
   * Adds row
   *
   * @return {TableDataSource} - updated data source instance
   * @method addRow
   */
  addRow() {
    const rows = this.rows();
    const nextRows = rows.concat([rows[0].map(() => null)]);
    return new TableDataSource({
      ...this._tableData,
      rows: nextRows,
    });
  }

  /**
   * Removes last row
   *
   * @return {TableDataSource} - updated data source instance
   * @method removeRow
   */
  removeRow() {
    const rows = this.rows();
    return new TableDataSource({
      ...this._tableData,
      rows: rows.slice(0, rows.length - 1),
    });
  }

  /**
   * Updates value for cell at given indices
   *
   * @param {object} args - args object
   * @param {number} args.rowIdx - rowIdx for cell
   * @param {number} args.colIdx - colIdx for cell
   * @param {boolean} args.isHeader - indicates whether cell is a header (column)
   * @param {any} args.value - new value for cell
   * @return {TableDataSource} - updated data source instance
   * @method updateCell
   */
  updateCell({ rowIdx, colIdx, isHeader, value } = {}) {
    if (isHeader) {
      const nextColumns = this.columns().slice();
      nextColumns.splice(colIdx, 1, value);
      return new TableDataSource({
        ...this._tableData,
        columns: nextColumns,
      });
    }

    const nextRows = this.rows().slice();
    const nextRow = nextRows[rowIdx].slice();
    nextRow.splice(colIdx, 1, value);
    nextRows[rowIdx] = nextRow;
    return new TableDataSource({
      ...this._tableData,
      rows: nextRows,
    });
  }

  /**
   * Clears all table data
   *
   * @return {TableDataSource} - updated data source instance
   * @method clear
   */
  clear() {
    return new TableDataSource();
  }

  filterRows(filterFn) {
    const rows = this.rows();
    const nextRows = rows.filter(filterFn);
    return new TableDataSource({
      ...this._tableData,
      rows: nextRows,
    });
  }

  toJSON() {
    return { ...this._tableData };
  }
}
