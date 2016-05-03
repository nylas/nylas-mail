import React, {Component, PropTypes} from 'react'
import RetinaImg from './retina-img'
import ReactDOM from 'react-dom'
import SelectableTable, {SelectableCell} from './selectable-table'


class EditableCell extends Component {

  static propTypes = {
    tableData: SelectableCell.propTypes.tableData,
    rowIdx: SelectableCell.propTypes.colIdx,
    colIdx: SelectableCell.propTypes.colIdx,
    isHeader: PropTypes.bool,
    inputProps: PropTypes.object,
    InputRenderer: SelectableTable.propTypes.RowRenderer,
    onAddRow: PropTypes.func,
    onCellEdited: PropTypes.func,
  }

  static defaultProps = {
    inputProps: {},
    InputRenderer: 'input',
  }

  componentDidMount() {
    if (this.shouldFocusInput()) {
      ReactDOM.findDOMNode(this.refs.inputContainer).querySelector('input').focus()
    }
  }

  componentDidUpdate() {
    if (this.shouldFocusInput()) {
      ReactDOM.findDOMNode(this.refs.inputContainer).querySelector('input').focus()
    }
  }

  onInputBlur(event) {
    const {target: {value}} = event
    const {tableData: {rows}, rowIdx, colIdx, onCellEdited} = this.props
    if (value && value !== rows[rowIdx][colIdx]) {
      onCellEdited({row: rowIdx, col: colIdx, value})
    }
  }

  onInputKeyDown(event) {
    const {key} = event
    const {onAddRow} = this.props

    if (['Enter', 'Return'].includes(key)) {
      if (this.refs.cell.isInLastRow()) {
        event.stopPropagation()
        onAddRow()
      }
    } else if (key === 'Escape') {
      event.stopPropagation()
      ReactDOM.findDOMNode(this.refs.inputContainer).focus()
    }
  }

  shouldFocusInput() {
    return (
      this.refs.cell.isSelectedUsingKey('Tab') ||
      this.refs.cell.isSelectedUsingKey('Enter') ||
      this.refs.cell.isSelectedUsingKey('Return')
    )
  }

  render() {
    const {rowIdx, colIdx, tableData, isHeader, inputProps, InputRenderer} = this.props
    const cellValue = tableData.rows[rowIdx][colIdx] || ''

    return (
      <SelectableCell ref="cell" {...this.props}>
        <div ref="inputContainer" tabIndex="0">
          <InputRenderer
            type="text"
            rowIdx={rowIdx}
            colIdx={colIdx}
            tableData={tableData}
            isHeader={isHeader}
            defaultValue={cellValue}
            onBlur={::this.onInputBlur}
            onKeyDown={::this.onInputKeyDown}
            {...inputProps}
          />
        </div>
      </SelectableCell>
    )
  }
}


class EditableTable extends Component {
  static displayName = 'EditableTable'

  static propTypes = {
    tableData: SelectableTable.propTypes.tableData,
    inputProps: PropTypes.object,
    InputRenderer: PropTypes.any,
    onCellEdited: PropTypes.func,
    onAddColumn: PropTypes.func,
    onRemoveColumn: PropTypes.func,
    onAddRow: PropTypes.func,
    onRemoveRow: PropTypes.func,
  }

  static defaultProps = {
    onCellEdited: () => {},
  }

  render() {
    const {
      inputProps,
      InputRenderer,
      onCellEdited,
      onAddRow,
      onRemoveRow,
      onAddColumn,
      onRemoveColumn,
      ...otherProps,
    } = this.props

    const tableProps = {
      ...otherProps,
      className: "editable-table",
      extraProps: {
        onAddRow,
        onRemoveRow,
        onCellEdited,
        inputProps,
        InputRenderer,
      },
      CellRenderer: EditableCell,
    }

    if (!onAddColumn || !onRemoveColumn) {
      return <SelectableTable {...tableProps} />
    }
    return (
      <div className="editable-table-container">
        <SelectableTable {...tableProps} />
        <div className="column-actions">
          <div className="btn btn-small" onClick={onAddColumn}>
            <RetinaImg
              name="icon-column-plus.png"
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </div>
          <div className="btn btn-small" onClick={onRemoveColumn}>
            <RetinaImg
              name="icon-column-minus.png"
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </div>
        </div>
      </div>
    )
  }
}

export default EditableTable
