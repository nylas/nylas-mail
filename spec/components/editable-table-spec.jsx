import React from 'react'
import ReactDOM from 'react-dom'
import {mount} from 'enzyme'
import {SelectableTable, EditableTableCell, EditableTable} from 'nylas-component-kit'
import {selection, cellProps, tableProps, testDataSource} from '../fixtures/table-data'


describe('EditableTable Components', function describeBlock() {
  describe('EditableTableCell', () => {
    function renderCell(props) {
      // This node is used so that React does not issue DOM tree warnings when running
      // the tests
      const table = document.createElement('table')
      table.innerHTML = '<tbody><tr></tr></tbody>'
      const cellRootNode = table.querySelector('tr')
      return mount(
        <EditableTableCell
          {...cellProps}
          {...props}
        />,
        {attachTo: cellRootNode}
      )
    }

    describe('onInputBlur', () => {
      it('should call onCellEdited if value is different from current value', () => {
        const onCellEdited = jasmine.createSpy('onCellEdited')
        const event = {
          target: {value: 'new-val'},
        }
        const cell = renderCell({onCellEdited, isHeader: false}).instance()
        cell.onInputBlur(event)
        expect(onCellEdited).toHaveBeenCalledWith({
          rowIdx: 0, colIdx: 0, value: 'new-val', isHeader: false,
        })
      });

      it('should not call onCellEdited otherwise', () => {
        const onCellEdited = jasmine.createSpy('onCellEdited')
        const event = {
          target: {value: 1},
        }
        const cell = renderCell({onCellEdited}).instance()
        cell.onInputBlur(event)
        expect(onCellEdited).not.toHaveBeenCalled()
      });
    });

    describe('onInputKeyDown', () => {
      it('calls onAddRow if Enter pressed and cell is in last row', () => {
        const onAddRow = jasmine.createSpy('onAddRow')
        const event = {
          key: 'Enter',
          stopPropagation: jasmine.createSpy('stopPropagation'),
        }
        const cell = renderCell({rowIdx: 2, onAddRow}).instance()
        cell.onInputKeyDown(event)
        expect(event.stopPropagation).toHaveBeenCalled()
        expect(onAddRow).toHaveBeenCalled()
      });

      it('stops event propagation and blurs input if Escape pressed', () => {
        const focusSpy = jasmine.createSpy('focusSpy')
        spyOn(ReactDOM, 'findDOMNode').andReturn({
          focus: focusSpy,
        })
        const event = {
          key: 'Escape',
          stopPropagation: jasmine.createSpy('stopPropagation'),
        }
        const cell = renderCell().instance()
        cell.onInputKeyDown(event)
        expect(event.stopPropagation).toHaveBeenCalled()
        expect(focusSpy).toHaveBeenCalled()
      });
    });

    it('renders a SelectableTableCell with the correct props', () => {
      const cell = renderCell()
      expect(cell.prop('tableDataSource')).toBe(testDataSource)
      expect(cell.prop('selection')).toBe(selection)
      expect(cell.prop('rowIdx')).toBe(0)
      expect(cell.prop('colIdx')).toBe(0)
    });

    it('renders the InputRenderer as the child of the SelectableTableCell with the correct props', () => {
      const InputRenderer = () => <input />
      const inputProps = {p1: 'p1'}
      const input = renderCell({
        rowIdx: 2,
        colIdx: 2,
        inputProps,
        InputRenderer,
      }).childAt(0).childAt(0)
      expect(input.type()).toBe(InputRenderer)
      expect(input.prop('rowIdx')).toBe(2)
      expect(input.prop('colIdx')).toBe(2)
      expect(input.prop('p1')).toBe('p1')
      expect(input.prop('defaultValue')).toBe(9)
      expect(input.prop('tableDataSource')).toBe(testDataSource)
    });
  });

  describe('EditableTable', () => {
    function renderTable(props) {
      return mount(
        <EditableTable
          {...tableProps}
          {...props}
        />
      )
    }

    it('renders column buttons if onAddColumn and onRemoveColumn are provided', () => {
      const onAddColumn = () => {}
      const onRemoveColumn = () => {}
      const table = renderTable({onAddColumn, onRemoveColumn})
      expect(table.hasClass('editable-table-container')).toBe(true)
      expect(table.find('.btn').length).toBe(2)
    });

    it('renders only a SelectableTable if column callbacks are not provided', () => {
      const table = renderTable()
      expect(table.find('.btn').length).toBe(0)
    });

    it('renders with the correct props', () => {
      const onAddRow = () => {}
      const onCellEdited = () => {}
      const inputProps = {}
      const InputRenderer = () => <input />
      const other = 'other'
      const table = renderTable({
        onAddRow,
        onCellEdited,
        inputProps,
        InputRenderer,
        other,
      }).find(SelectableTable)
      expect(table.prop('extraProps').onAddRow).toBe(onAddRow)
      expect(table.prop('extraProps').onCellEdited).toBe(onCellEdited)
      expect(table.prop('extraProps').inputProps).toBe(inputProps)
      expect(table.prop('extraProps').InputRenderer).toBe(InputRenderer)
      expect(table.prop('other')).toEqual('other')
      expect(table.prop('CellRenderer')).toBe(EditableTableCell)
      expect(table.prop('className')).toEqual('editable-table')
    });
  });
});

