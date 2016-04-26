import _ from 'underscore'
import classnames from 'classnames'
import React, {Component, PropTypes} from 'react'


// TODO Ugh gross. Use flow
const RowDataType = PropTypes.arrayOf(PropTypes.node)
const RendererType = PropTypes.oneOfType([PropTypes.func, PropTypes.string])
const IndexType = PropTypes.oneOfType([PropTypes.number, PropTypes.string])
const TablePropTypes = {
  idx: IndexType,
  renderer: RendererType,
  tableData: PropTypes.shape({
    rows: PropTypes.arrayOf(RowDataType),
  }),
}


export class TableCell extends Component {

  static propTypes = {
    className: PropTypes.string,
    isHeader: PropTypes.bool,
    tableData: TablePropTypes.tableData.isRequired,
    rowIdx: TablePropTypes.idx.isRequired,
    colIdx: TablePropTypes.idx.isRequired,
  }

  static defaultProps = {
    className: '',
  }

  render() {
    const {className, isHeader, children, ...props} = this.props
    const CellTag = isHeader ? 'th' : 'td'
    return (
      <CellTag {...props} className={`table-cell ${className}`} >
        {children}
      </CellTag>
    )
  }
}


export class TableRow extends Component {

  static propTypes = {
    className: PropTypes.string,
    isHeader: PropTypes.bool,
    displayNumbers: PropTypes.bool,
    tableData: TablePropTypes.tableData.isRequired,
    rowIdx: TablePropTypes.idx.isRequired,
    extraProps: PropTypes.object,
    CellRenderer: TablePropTypes.renderer,
  }

  static defaultProps = {
    className: '',
    extraProps: {},
    CellRenderer: TableCell,
  }

  render() {
    const {className, displayNumbers, isHeader, tableData, rowIdx, extraProps, CellRenderer, ...props} = this.props
    const classes = classnames({
      'table-row': true,
      'table-row-header': isHeader,
      [className]: true,
    })

    return (
      <tr className={classes} {...props} >
        {displayNumbers ?
          <TableCell
            className="numbered-cell"
            rowIdx={null}
            colIdx={null}
            tableData={{}}
            isHeader={isHeader}
          >
            {isHeader ? '' : rowIdx}
          </TableCell> :
          null
        }
        {_.times(tableData.rows[0].length, (colIdx) => {
          const cellProps = {tableData, rowIdx, colIdx, ...extraProps}
          return (
            <CellRenderer key={`cell-${rowIdx}-${colIdx}`} {...cellProps}>
              {tableData.rows[rowIdx][colIdx]}
            </CellRenderer>
          )
        })}
      </tr>
    )
  }
}


export default class Table extends Component {

  static propTypes = {
    className: PropTypes.string,
    displayHeader: PropTypes.bool,
    displayNumbers: PropTypes.bool,
    tableData: TablePropTypes.tableData.isRequired,
    extraProps: PropTypes.object,
    RowRenderer: TablePropTypes.renderer,
    CellRenderer: TablePropTypes.renderer,
  }

  static defaultProps = {
    className: '',
    extraProps: {},
    RowRenderer: TableRow,
    CellRenderer: TableCell,
  }

  renderBody() {
    const {tableData, displayNumbers, displayHeader, extraProps, RowRenderer, CellRenderer} = this.props
    const rows = displayHeader ? tableData.rows.slice(1) : tableData.rows

    const rowElements = rows.map((row, idx) => {
      const rowIdx = displayHeader ? idx + 1 : idx;
      return (
        <RowRenderer
          key={`row-${rowIdx}`}
          rowIdx={rowIdx}
          displayNumbers={displayNumbers}
          tableData={tableData}
          extraProps={extraProps}
          CellRenderer={CellRenderer}
          {...extraProps}
        />
      )
    })

    return (
      <tbody>
        {rowElements}
      </tbody>
    )
  }

  renderHeader() {
    const {tableData, displayNumbers, displayHeader, extraProps, RowRenderer, CellRenderer} = this.props
    if (!displayHeader) { return false }

    const extraHeaderProps = {...extraProps, isHeader: true}
    return (
      <thead>
        <RowRenderer
          rowIdx={0}
          tableData={tableData}
          displayNumbers={displayNumbers}
          extraProps={extraHeaderProps}
          CellRenderer={CellRenderer}
          {...extraHeaderProps}
        />
      </thead>
    )
  }

  render() {
    const {className} = this.props

    return (
      <div className={`nylas-table ${className}`}>
        <table>
          {this.renderHeader()}
          {this.renderBody()}
        </table>
      </div>
    )
  }
}
