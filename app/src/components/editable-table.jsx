import React, { Component } from 'react';
import { pickHTMLProps } from 'pick-react-known-prop';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

import RetinaImg from './retina-img';
import SelectableTable, { SelectableTableCell } from './selectable-table';

/*
 * EditableTable component which renders a {SelectableTable} that supports
 * editing cells, and adding new rows and columns
 *
 * The required props for EditableTable are the same for {SelectableTable} plus
 * the function `onCellEdited`, which is of the form:
 *
 * ```
 *   const onCellEdited = ({rowIdx, colIdx, isHeader, value}) => { ... }
 * ```
 *
 * EditableTable is a controlled component, which means that it does not
 * manage any internal state. In order for the values of cells to be updated, or to add
 * new rows or columns, the functions `onCellEdited`, `onAddRow`, `onAddColumn`,
 * `onRemoveColumn` must be provided as props, and must eventually trigger
 * a re render of this Component with a new set of props.
 *
 * If the function `onAddColumn` and `onRemoveColumns` are provided, this
 * component will render a set of buttons to add and remove columns
 *
 * EditableTable takes the exact same set of props as {SelectableTable}, plus
 * additional props documented below. For {SelectableTable} props, see the docs
 * for {SelectableTable}
 *
 * @param {object} props - props for EditableTable
 * @param {object} props.inputProps - props to pass to the InputRenderer
 * @param {function | string} props.InputRenderer - Function, Class or String used
 * to render the inputs for cells. Defaults to <input />. Must be of any type
 * accepted by React.createElement. E.g. 'div', () => <div />,
 * class Div extends React.Component { render() { return <div /> } }
 * @param {props.onCellEdited} props.onCellEdited
 * @param {props.onAddRow} props.onAddRow
 * @param {props.onAddColumn} props.onAddColumn
 * @param {props.onRemoveColumn} props.onRemoveColumn
 * @class EditableTable
 */
/*
 * This function will be called when a cell has been edited witha new value
 * @callback props.onCellEdited
 * @param {object} args - object containing indices for the cell and the new
 * value
 * @param {number} args.row - row index for the edited cell
 * @param {number} args.col - column index for the edited cell
 * @param {string} args.value - value for the cell
 */
/*
 * This function will be called when a row needs to be added
 * @callback props.onAddRow
 */
/*
 * This function will be called when a column needs to be added
 * @callback props.onAddColumn
 */
/*
 * This function will be called when the last column needs to be removed
 * @callback props.onRemoveColumn
 */

export class EditableTableCell extends Component {
  static propTypes = {
    tableDataSource: SelectableTableCell.propTypes.tableDataSource,
    rowIdx: SelectableTableCell.propTypes.colIdx,
    colIdx: SelectableTableCell.propTypes.colIdx,
    isHeader: PropTypes.bool,
    inputProps: PropTypes.object,
    InputRenderer: SelectableTable.propTypes.RowRenderer,
    onAddRow: PropTypes.func,
    onCellEdited: PropTypes.func.isRequired,
  };

  static defaultProps = {
    inputProps: {},
    InputRenderer: props => <input {...pickHTMLProps(props)} defaultValue={props.defaultValue} />,
  };

  componentDidMount() {
    if (this.shouldFocusInput()) {
      ReactDOM.findDOMNode(this.refs.inputContainer)
        .querySelector('input')
        .focus();
    }
  }

  componentDidUpdate() {
    if (this.shouldFocusInput()) {
      ReactDOM.findDOMNode(this.refs.inputContainer)
        .querySelector('input')
        .focus();
    }
  }

  onInputBlur = event => {
    const { target: { value } } = event;
    const { tableDataSource, isHeader, rowIdx, colIdx, onCellEdited } = this.props;
    const currentValue = tableDataSource.cellAt({ rowIdx, colIdx });
    if (value != null && value !== currentValue) {
      onCellEdited({ rowIdx, colIdx, isHeader, value });
    }
  };

  onInputKeyDown = event => {
    const { key } = event;
    const { onAddRow } = this.props;

    if (['Enter', 'Return'].includes(key)) {
      if (this.refs.cell.isInLastRow()) {
        event.stopPropagation();
        onAddRow();
      }
    } else if (key === 'Escape') {
      event.stopPropagation();
      ReactDOM.findDOMNode(this.refs.inputContainer).focus();
    }
  };

  shouldFocusInput() {
    return (
      this.refs.cell.isSelectedUsingKey('Tab') ||
      this.refs.cell.isSelectedUsingKey('Enter') ||
      this.refs.cell.isSelectedUsingKey('Return')
    );
  }

  render() {
    const { rowIdx, colIdx, tableDataSource, isHeader, inputProps, InputRenderer } = this.props;
    const cellValue = tableDataSource.cellAt({ rowIdx, colIdx });

    return (
      <SelectableTableCell ref="cell" {...this.props}>
        <div ref="inputContainer" tabIndex="0">
          <InputRenderer
            type="text"
            rowIdx={rowIdx}
            colIdx={colIdx}
            tableDataSource={tableDataSource}
            isHeader={isHeader}
            defaultValue={cellValue}
            onBlur={this.onInputBlur}
            onKeyDown={this.onInputKeyDown}
            {...inputProps}
          />
        </div>
      </SelectableTableCell>
    );
  }
}

function EditableTable(props) {
  const {
    inputProps,
    InputRenderer,
    onCellEdited,
    onAddRow,
    onRemoveRow,
    onAddColumn,
    onRemoveColumn,
    ...otherProps
  } = props;

  const tableProps = {
    ...otherProps,
    className: 'editable-table',
    extraProps: {
      onAddRow,
      onRemoveRow,
      onCellEdited,
      inputProps,
      InputRenderer,
    },
    CellRenderer: EditableTableCell,
  };

  if (!onAddColumn || !onRemoveColumn) {
    return <SelectableTable {...tableProps} />;
  }
  return (
    <div className="editable-table-container">
      <SelectableTable {...tableProps} />
      <div className="column-actions">
        <div className="btn btn-small" onClick={onAddColumn}>
          <RetinaImg name="icon-column-plus.png" mode={RetinaImg.Mode.ContentPreserve} />
        </div>
        <div className="btn btn-small" onClick={onRemoveColumn}>
          <RetinaImg name="icon-column-minus.png" mode={RetinaImg.Mode.ContentPreserve} />
        </div>
      </div>
    </div>
  );
}

EditableTable.displayName = 'EditableTable';

EditableTable.propTypes = {
  tableDataSource: SelectableTable.propTypes.tableDataSource,
  inputProps: PropTypes.object,
  InputRenderer: PropTypes.any,
  onCellEdited: PropTypes.func.isRequired,
  onAddColumn: PropTypes.func,
  onRemoveColumn: PropTypes.func,
  onAddRow: PropTypes.func,
  onRemoveRow: PropTypes.func,
};

export default EditableTable;
