import classnames from 'classnames';
import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { pickHTMLProps } from 'pick-react-known-prop';
import LazyRenderedList from '../lazy-rendered-list';
import TableDataSource from './table-data-source';

/*
 * Scrollable Table component which supports headers, numbering and lazily rendering rows.
 * The only required prop is `tableDataSource` which must be an instance of
 * {TableDataSource}:
 *
 * ```
 * const tableDataSource = new TableDataSource()
 * tableDataSource.rows()
 * // returns
 * // [
 * //   [1, 2],
 * //   [3, 4],
 * // ]
 * ```
 *
 * In order to lazily render rows, the props `rowHeight` and `tableBodyHeight`
 * are required.
 *
 * The Table Component can be extended via passing custom `RowRenderer` and
 * `CellRenderer` components as props. Any `RowRenderer` or `CellRenderer`
 * passed to Table must internally render a {TableRow} or {TableCell} component,
 * which are also exported in this module.
 *
 * See {SelectableTable} for an example of extending this component
 *
 * @param {object} props - props for Table
 * @param {string} props.className - CSS class to be applied to component
 * @param {boolean} props.displayNumbers - Wether to display a column with row
 * numberings
 * @param {boolean} props.displayHeader - Wether to display the first row in the
 * table data as a header
 * @param {number} props.rowHeight - Height of every row in the table
 * @param {number} props.tableBodyHeight - Height of the table body, excluding
 * the header
 * @param {object} props.tableDataSource - Instance of {TableDataSource} which
 * provides table data to be rendered
 * @param {object} props.extraProps - Additional props to be passed down to
 * `RowRenderer` and `CellRenderer` components
 * @param {function | string} props.RowRenderer - Function, Class or String used
 * to render Rows. Must be of any type accepted by React.createElement. E.g.
 * 'div', () => <div />, class Div extends React.Component { render() { return <div /> } }
 * @param {function | string} props.CellRenderer - Function, Class or String used
 * to render Cells. Must be of any type accepted by React.createElement. E.g.
 * 'div', () => <div />, class Div extends React.Component { render() { return <div /> } }
 * @class Table
 */

const RendererType = PropTypes.oneOfType([PropTypes.func, PropTypes.string]);
const IndexType = PropTypes.oneOfType([PropTypes.number, PropTypes.string]);
const TablePropTypes = {
  idx: IndexType,
  renderer: RendererType,
  tableDataSource: PropTypes.instanceOf(TableDataSource),
};

export function TableCell(props) {
  const { className, isHeader, children, ...extraProps } = props;
  const CellTag = isHeader ? 'th' : 'td';
  return (
    <CellTag {...pickHTMLProps(extraProps)} className={`table-cell ${className}`}>
      {children}
    </CellTag>
  );
}

TableCell.propTypes = {
  isHeader: PropTypes.bool,
  className: PropTypes.string,
};

export class TableRow extends Component {
  static propTypes = {
    className: PropTypes.string,
    isHeader: PropTypes.bool,
    displayNumbers: PropTypes.bool,
    tableDataSource: TablePropTypes.tableDataSource.isRequired,
    rowIdx: TablePropTypes.idx,
    extraProps: PropTypes.object,
    CellRenderer: TablePropTypes.renderer,
  };

  static defaultProps = {
    className: '',
    extraProps: {},
    CellRenderer: TableCell,
  };

  render() {
    const {
      className,
      displayNumbers,
      isHeader,
      tableDataSource,
      rowIdx,
      extraProps,
      CellRenderer,
      ...props
    } = this.props;
    const classes = classnames({
      'table-row': true,
      'table-row-header': isHeader,
      [className]: true,
    });

    return (
      <tr className={classes} {...pickHTMLProps(props)}>
        {displayNumbers ? (
          <TableCell className="numbered-cell" isHeader={isHeader}>
            {isHeader ? '' : rowIdx + 1}
          </TableCell>
        ) : null}
        {tableDataSource.columns().map((colName, colIdx) => {
          const cellProps = { tableDataSource, rowIdx, colIdx, ...extraProps };
          return (
            <CellRenderer key={`cell-${rowIdx}-${colIdx}`} {...cellProps}>
              {tableDataSource.cellAt({ rowIdx, colIdx })}
            </CellRenderer>
          );
        })}
      </tr>
    );
  }
}

export default class Table extends Component {
  static displayName = 'Table';

  static propTypes = {
    className: PropTypes.string,
    displayHeader: PropTypes.bool,
    displayNumbers: PropTypes.bool,
    rowHeight: PropTypes.number,
    bodyHeight: PropTypes.number,
    tableDataSource: TablePropTypes.tableDataSource.isRequired,
    extraProps: PropTypes.object,
    RowRenderer: TablePropTypes.renderer,
    CellRenderer: TablePropTypes.renderer,
  };

  static defaultProps = {
    className: '',
    extraProps: {},
    RowRenderer: TableRow,
    CellRenderer: TableCell,
  };

  static TableDataSource = TableDataSource;

  renderRow = ({ idx }) => {
    const { tableDataSource, displayNumbers, extraProps, RowRenderer, CellRenderer } = this.props;
    return (
      <RowRenderer
        key={`row-${idx}`}
        rowIdx={idx}
        displayNumbers={displayNumbers}
        tableDataSource={tableDataSource}
        extraProps={extraProps}
        CellRenderer={CellRenderer}
        {...extraProps}
      />
    );
  };

  renderBody() {
    const { tableDataSource, rowHeight, bodyHeight } = this.props;
    const rows = tableDataSource.rows();

    return (
      <LazyRenderedList
        items={rows}
        itemHeight={rowHeight}
        containerHeight={bodyHeight}
        BufferTag="tr"
        RootRenderer="tbody"
        ItemRenderer={this.renderRow}
      />
    );
  }

  renderHeader() {
    const {
      tableDataSource,
      displayNumbers,
      displayHeader,
      extraProps,
      RowRenderer,
      CellRenderer,
    } = this.props;
    if (!displayHeader) {
      return false;
    }

    const extraHeaderProps = { ...extraProps, isHeader: true };
    return (
      <thead>
        <RowRenderer
          rowIdx={null}
          tableDataSource={tableDataSource}
          displayNumbers={displayNumbers}
          extraProps={extraHeaderProps}
          CellRenderer={CellRenderer}
          {...extraHeaderProps}
        />
      </thead>
    );
  }

  render() {
    const { className, ...otherProps } = this.props;

    return (
      <div className={`nylas-table ${className}`} {...pickHTMLProps(otherProps)}>
        <table>
          {this.renderHeader()}
          {this.renderBody()}
        </table>
      </div>
    );
  }
}
