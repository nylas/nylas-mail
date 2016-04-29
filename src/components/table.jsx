import _ from 'underscore'
import classnames from 'classnames'
import React, {Component, PropTypes} from 'react'
import LazyRenderedList from './lazy-rendered-list'


const RendererType = PropTypes.oneOfType([PropTypes.func, PropTypes.string])
const IndexType = PropTypes.oneOfType([PropTypes.number, PropTypes.string])
const TablePropTypes = {
  idx: IndexType,
  renderer: RendererType,
  tableData: PropTypes.shape({
    rows: PropTypes.array,
  }),
}

export function TableCell({className = '', isHeader, children, ...props}) {
  const CellTag = isHeader ? 'th' : 'td'
  return (
    <CellTag {...props} className={`table-cell ${className}`} >
      {children}
    </CellTag>
  )
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
    rowHeight: PropTypes.number,
    bodyHeight: PropTypes.number,
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

  renderRow = ({idx}) => {
    const {tableData, displayNumbers, displayHeader, extraProps, RowRenderer, CellRenderer} = this.props
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
  }

  renderBody() {
    const {tableData, rowHeight, bodyHeight, displayHeader} = this.props
    const rows = displayHeader ? tableData.rows.slice(1) : tableData.rows

    return (
      <LazyRenderedList
        items={rows}
        itemHeight={rowHeight}
        containerHeight={bodyHeight}
        BufferTag="tr"
        ItemRenderer={this.renderRow}
        RootRenderer="tbody"
      />
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
    const {className, ...otherProps} = this.props

    return (
      <div className={`nylas-table ${className}`} {...otherProps}>
        <table>
          {this.renderHeader()}
          {this.renderBody()}
        </table>
      </div>
    )
  }
}
