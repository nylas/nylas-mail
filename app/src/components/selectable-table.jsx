import _ from 'underscore';
import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import classnames from 'classnames';
import compose from './decorators/compose';
import AutoFocuses from './decorators/auto-focuses';
import ListensToMovementKeys from './decorators/listens-to-movement-keys';
import Table, { TableRow, TableCell } from './table/table';
import PropTypes from 'prop-types';

/*
SelectableTable component which renders a {Table} that supports selecting
cells and rows.

The required props for SelectableTable are `tableDataSource`, `selection`,
`onSetSelection`, `onShiftSelection`, which are of the form:

```
const tableDataSource = new TableDataSource()
tableDataSource.rows()
// returns
// [
//   [1, 2],
//   [3, 4],
// ]

const selection = {rowIdx: 1, colIdx: 0, key: 'Enter'}

const onSetSelection = ({rowIdx, colIdx, key}) => { ... }

const onShiftSelection = ({row, col, key}) => { ... }
```

SelectableTable is a controlled component, which means that it does not
manage any internal state. In order for the selection to be updated, the
functions `onShiftSelection` and `onSetSelection` must be provided as props,
and must eventually trigger a re render of this Component with a new set of
props.

The SelectableTable Component can be extended via passing custom `RowRenderer` and
`CellRenderer` components as props, in the same manner that the {Table}
component can be extended. See the docs for {Table} for more details

SelectableTable takes the exact same set of props as {Table}, plus additional
props documented below. For {Table} props, see the docs for {Table}

@param {object} props - props for SelectableTable
@param {string} props.className - CSS class to be applied to component
@param {object} props.selection - Object representing selection indices, plus
the key with which the selection was established. It * is of the form {row,
col, key}
@param {props.onSetSelection} props.onSetSelection
@param {props.onShiftSelection} props.onSetSelection
@class SelectableTable


This function will be called when the selection needs to be set to the
selection passed in as a parameter
@callback props.onSetSelection
@param {object} selection - selection object of the form {rowIdx, colIdx, key}
@param {number} selection.rowIdx - rowIdx for selection
@param {number} selection.colIdx - colIds for selection


This function will be called when the selection row and col indices need to
be shifted by a specific delta
@callback props.onShiftSelection
@param {object} selectionDeltas - selection object of the form {row, col, key}
@param {number} selectionDeltas.row - number representing by how many rows to
move the selection. E.g. 1, -2.
@param {number} selectionDeltas.col - number representing by how many columns to
move the selection. E.g. 1, -2.
@param {string} selectionDeltas.key - string that represents the key used to
shift the selection
 */
export class SelectableTableCell extends Component {
  static propTypes = {
    className: PropTypes.string,
    tableDataSource: Table.propTypes.tableDataSource,
    rowIdx: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    colIdx: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    selection: PropTypes.object,
    onSetSelection: PropTypes.func.isRequired,
  };

  static defaultProps = {
    className: '',
  };

  shouldComponentUpdate(nextProps) {
    const cellValueChanged =
      this.props.tableDataSource.cellAt({
        rowIdx: this.props.rowIdx,
        colIdx: this.props.colIdx,
      }) !==
      nextProps.tableDataSource.cellAt({ rowIdx: nextProps.rowIdx, colIdx: nextProps.colIdx });
    const selectionStateChanged = this.isSelected(this.props) !== this.isSelected(nextProps);
    return cellValueChanged || selectionStateChanged;
  }

  onClickCell = () => {
    const { selection, rowIdx, colIdx, onSetSelection } = this.props;
    if (_.isEqual(selection, { row: rowIdx, col: colIdx })) {
      return;
    }
    onSetSelection({ rowIdx, colIdx, key: null });
  };

  isSelected({ selection, rowIdx, colIdx }) {
    return selection && selection.rowIdx === rowIdx && selection.colIdx === colIdx;
  }

  isSelectedUsingKey(key) {
    const { selection } = this.props;
    return this.isSelected(this.props) && selection.key === key;
  }

  isInLastRow() {
    const { rowIdx, tableDataSource } = this.props;
    const rows = tableDataSource.rows();
    return rowIdx === rows.length - 1;
  }

  render() {
    const { className } = this.props;
    const classes = classnames({
      [className]: true,
      selected: this.isSelected(this.props),
    });
    return <TableCell {...this.props} className={classes} onClick={this.onClickCell} />;
  }
}

export class SelectableTableRow extends Component {
  static propTypes = {
    className: PropTypes.string,
    tableDataSource: Table.propTypes.tableDataSource,
    selection: PropTypes.object,
    rowIdx: TableRow.propTypes.rowIdx,
  };

  static defaultProps = {
    className: '',
  };

  shouldComponentUpdate(nextProps) {
    const rowChanged =
      this.props.tableDataSource.rowAt(this.props.rowIdx) !==
      nextProps.tableDataSource.rowAt(nextProps.rowIdx);
    const selectionStateChanged = this.isSelected(this.props) !== this.isSelected(nextProps);
    const selectedColChanged = this.props.selection.colIdx !== nextProps.selection.colIdx;

    return rowChanged || selectionStateChanged || selectedColChanged;
  }

  componentDidUpdate() {
    if (this.isSelected(this.props)) {
      ReactDOM.findDOMNode(this).scrollIntoViewIfNeeded(false);
    }
  }

  isSelected({ selection, rowIdx }) {
    return selection && selection.rowIdx === rowIdx;
  }

  render() {
    const { className } = this.props;
    const classes = classnames({
      [className]: true,
      selected: this.isSelected(this.props),
    });
    return <TableRow {...this.props} className={classes} />;
  }
}

class SelectableTable extends Component {
  static displayName = 'SelectableTable';

  static propTypes = {
    tableDataSource: Table.propTypes.tableDataSource,
    extraProps: PropTypes.object,
    RowRenderer: Table.propTypes.RowRenderer,
    CellRenderer: Table.propTypes.CellRenderer,
    selection: PropTypes.shape({
      rowIdx: PropTypes.number,
      colIdx: PropTypes.number,
    }).isRequired,
    onSetSelection: PropTypes.func.isRequired,
    onShiftSelection: PropTypes.func.isRequired,
  };

  static defaultProps = {
    extraProps: {},
    RowRenderer: SelectableTableRow,
    CellRenderer: SelectableTableCell,
  };

  shouldComponentUpdate(nextProps) {
    return (
      this.props.tableDataSource !== nextProps.tableDataSource ||
      this.props.selection !== nextProps.selection
    );
  }

  onArrowUp({ key }) {
    const { onShiftSelection } = this.props;
    onShiftSelection({ row: -1, key });
  }

  onArrowDown({ key }) {
    const { onShiftSelection } = this.props;
    onShiftSelection({ row: 1, key });
  }

  onArrowLeft({ key }) {
    const { onShiftSelection } = this.props;
    onShiftSelection({ col: -1, key });
  }

  onArrowRight({ key }) {
    const { onShiftSelection } = this.props;
    onShiftSelection({ col: 1, key });
  }

  onEnter({ key }) {
    const { onShiftSelection } = this.props;
    onShiftSelection({ row: 1, key });
  }

  onTab({ key }) {
    const { tableDataSource, selection, onShiftSelection } = this.props;
    const colLen = tableDataSource.columns().length;
    if (selection.colIdx === colLen - 1) {
      onShiftSelection({ row: 1, col: -(colLen - 1), key });
    } else {
      onShiftSelection({ col: 1, key });
    }
  }

  onShiftTab({ key }) {
    const { tableDataSource, selection, onShiftSelection } = this.props;
    const colLen = tableDataSource.columns().length;
    if (selection.colIdx === 0) {
      onShiftSelection({ row: -1, col: colLen - 1, key });
    } else {
      onShiftSelection({ col: -1, key });
    }
  }

  render() {
    const {
      selection,
      onSetSelection,
      onShiftSelection,
      extraProps,
      RowRenderer,
      CellRenderer,
    } = this.props;
    const selectionProps = {
      selection,
      onSetSelection,
      onShiftSelection,
    };

    return (
      <Table
        {...this.props}
        extraProps={{ ...extraProps, ...selectionProps }}
        RowRenderer={RowRenderer}
        CellRenderer={CellRenderer}
      />
    );
  }
}

export default compose(SelectableTable, ListensToMovementKeys, Comp =>
  AutoFocuses(Comp, { onUpdate: false })
);
