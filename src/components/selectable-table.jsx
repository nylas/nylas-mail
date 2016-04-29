import _ from 'underscore'
import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import classnames from 'classnames';
import compose from './decorators/compose';
import AutoFocuses from './decorators/auto-focuses';
import ListensToMovementKeys from './decorators/listens-to-movement-keys';
import Table, {TableRow, TableCell} from './table'


export class SelectableCell extends Component {

  static propTypes = {
    className: PropTypes.string,
    tableData: Table.propTypes.tableData,
    rowIdx: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    colIdx: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    selection: PropTypes.object,
    onSetSelection: PropTypes.func.isRequired,
  }

  static defaultProps = {
    className: '',
  }

  shouldComponentUpdate(nextProps) {
    return (
      this.props.tableData.rows[this.props.rowIdx][this.props.colIdx] !== nextProps.tableData.rows[nextProps.rowIdx][nextProps.colIdx] ||
      this.isSelected(this.props) !== this.isSelected(nextProps)
    )
  }

  onClickCell() {
    const {selection, rowIdx, colIdx, onSetSelection} = this.props
    if (_.isEqual(selection, {row: rowIdx, col: colIdx})) { return }
    onSetSelection({row: rowIdx, col: colIdx, key: null})
  }

  isSelected({selection, rowIdx, colIdx}) {
    return (
      selection && selection.row === rowIdx && selection.col === colIdx
    )
  }

  isSelectedUsingKey(key) {
    const {selection} = this.props
    return this.isSelected(this.props) && selection.key === key
  }

  isInLastRow() {
    const {rowIdx, tableData: {rows}} = this.props
    return rowIdx === rows.length - 1;
  }

  render() {
    const {className} = this.props
    const classes = classnames({
      [className]: true,
      'selected': this.isSelected(this.props),
    })
    return (
      <TableCell
        {...this.props}
        className={classes}
        onClick={::this.onClickCell}
      />
    )
  }
}


export class SelectableRow extends Component {

  static propTypes = {
    className: PropTypes.string,
    tableData: Table.propTypes.tableData,
    selection: PropTypes.object,
    rowIdx: TableRow.propTypes.rowIdx,
  }

  static defaultProps = {
    className: '',
  }

  shouldComponentUpdate(nextProps) {
    return (
      this.props.tableData.rows[this.props.rowIdx] !== nextProps.tableData.rows[nextProps.rowIdx] ||
      this.isSelected(this.props) !== this.isSelected(nextProps) ||
      this.props.selection.col !== nextProps.selection.col
    )
  }

  componentDidUpdate() {
    if (this.isSelected(this.props)) {
      ReactDOM.findDOMNode(this)
      .scrollIntoViewIfNeeded(false)
    }
  }

  isSelected({selection, rowIdx}) {
    return selection && selection.row === rowIdx
  }

  render() {
    const {className} = this.props
    const classes = classnames({
      [className]: true,
      'selected': this.isSelected(this.props),
    })
    return (
      <TableRow
        {...this.props}
        className={classes}
      />
    )
  }
}


class SelectableTable extends Component {
  static displayName = 'SelectableTable'

  static propTypes = {
    tableData: Table.propTypes.tableData,
    extraProps: PropTypes.object,
    RowRenderer: Table.propTypes.RowRenderer,
    CellRenderer: Table.propTypes.CellRenderer,
    selection: PropTypes.shape({
      row: PropTypes.number,
      col: PropTypes.number,
    }).isRequired,
    onSetSelection: PropTypes.func.isRequired,
    onShiftSelection: PropTypes.func.isRequired,
  }

  static defaultProps = {
    extraProps: {},
    RowRenderer: SelectableRow,
    CellRenderer: SelectableCell,
  }

  shouldComponentUpdate(nextProps) {
    return (
      this.props.tableData !== nextProps.tableData ||
      this.props.selection !== nextProps.selection
    )
  }

  onArrowUp({key}) {
    const {onShiftSelection} = this.props
    onShiftSelection({row: -1, key})
  }

  onArrowDown({key}) {
    const {onShiftSelection} = this.props
    onShiftSelection({row: 1, key})
  }

  onArrowLeft({key}) {
    const {onShiftSelection} = this.props
    onShiftSelection({col: -1, key})
  }

  onArrowRight({key}) {
    const {onShiftSelection} = this.props
    onShiftSelection({col: 1, key})
  }

  onEnter({key}) {
    const {onShiftSelection} = this.props
    onShiftSelection({row: 1, key})
  }

  onTab({key}) {
    const {tableData, selection, onShiftSelection} = this.props
    const colLen = tableData.rows[0].length
    if (selection.col === colLen - 1) {
      onShiftSelection({row: 1, col: -(colLen - 1), key})
    } else {
      onShiftSelection({col: 1, key})
    }
  }

  onShiftTab({key}) {
    const {tableData, selection, onShiftSelection} = this.props
    const colLen = tableData.rows[0].length
    if (selection.col === 0) {
      onShiftSelection({row: -1, col: colLen - 1, key})
    } else {
      onShiftSelection({col: -1, key})
    }
  }

  render() {
    const {selection, onSetSelection, onShiftSelection, extraProps, RowRenderer, CellRenderer} = this.props
    const selectionProps = {
      selection,
      onSetSelection,
      onShiftSelection,
    }

    return (
      <Table
        {...this.props}
        extraProps={{...extraProps, ...selectionProps}}
        RowRenderer={RowRenderer}
        CellRenderer={CellRenderer}
      />
    )
  }
}

export default compose(
  SelectableTable,
  ListensToMovementKeys,
  (Comp) => AutoFocuses(Comp, {onUpdate: false})
)
