import React from 'react'
import {mount, shallow} from 'enzyme'
import {Table, SelectableTableCell, SelectableTableRow, SelectableTable} from 'mailspring-component-kit'
import {selection, cellProps, rowProps, tableProps, testDataSource} from '../fixtures/table-data'


describe('SelectableTable Components', function describeBlock() {
  describe('SelectableTableCell', () => {
    function renderCell(props) {
      return shallow(
        <SelectableTableCell
          {...cellProps}
          {...props}
        />
      )
    }

    describe('shouldComponentUpdate', () => {
      it('should update if selection status for cell has changed', () => {
        const nextSelection = {colIdx: 0, rowIdx: 2}
        const cell = renderCell()
        const nextProps = {...cellProps, selection: nextSelection}
        const shouldUpdate = cell.instance().shouldComponentUpdate(nextProps)
        expect(shouldUpdate).toBe(true)
      });

      it('should update if data for cell has changed', () => {
        const nextRows = testDataSource.rows().slice()
        nextRows[0] = ['something else', 2]
        const nextDataSource = testDataSource.setRows(nextRows)
        const cell = renderCell()
        const nextProps = {...cellProps, tableDataSource: nextDataSource}
        const shouldUpdate = cell.instance().shouldComponentUpdate(nextProps)
        expect(shouldUpdate).toBe(true)
      });

      it('should not update otherwise', () => {
        const nextRows = testDataSource.rows().slice()
        nextRows[0] = nextRows[0].slice()
        const nextDataSource = testDataSource.setRows(nextRows)
        const nextSelection = {...selection}
        const cell = renderCell()
        const nextProps = {...cellProps, selection: nextSelection, tableDataSource: nextDataSource}
        const shouldUpdate = cell.instance().shouldComponentUpdate(nextProps)
        expect(shouldUpdate).toBe(false)
      });
    });

    describe('isSelected', () => {
      it('returns true if selection matches props', () => {
        const cell = renderCell()
        expect(cell.instance().isSelected(cellProps)).toBe(true)
      });

      it('returns false otherwise', () => {
        const cell = renderCell()
        expect(cell.instance().isSelected({
          ...cellProps,
          selection: {rowIdx: 1, colIdx: 2},
        })).toBe(false)
      });
    });

    describe('isSelectedUsingKey', () => {
      it('returns true if cell was selected using the provided key', () => {
        const cell = renderCell({selection: {...selection, key: 'Enter'}})
        expect(cell.instance().isSelectedUsingKey('Enter')).toBe(true)
      });

      it('returns false if cell was not selected using the provided key', () => {
        const cell = renderCell()
        expect(cell.instance().isSelectedUsingKey('Enter')).toBe(false)
      });
    });

    describe('isInLastRow', () => {
      it('returns true if cell is in last row', () => {
        const cell = renderCell({rowIdx: 2})
        expect(cell.instance().isInLastRow()).toBe(true)
      });

      it('returns true if cell is not in last row', () => {
        const cell = renderCell()
        expect(cell.instance().isInLastRow()).toBe(false)
      });
    });

    it('renders with the appropriate className when selected', () => {
      const cell = renderCell()
      expect(cell.hasClass('selected')).toBe(true)
    });

    it('renders with the appropriate className when not selected', () => {
      const cell = renderCell({rowIdx: 2, colIdx: 1})
      expect(cell.hasClass('selected')).toBe(false)
    });

    it('renders any extra classNames', () => {
      const cell = renderCell({className: 'my-cell'})
      expect(cell.hasClass('my-cell')).toBe(true)
    });
  });

  describe('SelectableTableRow', () => {
    function renderRow(props) {
      return shallow(
        <SelectableTableRow
          {...rowProps}
          {...props}
        />
      )
    }

    describe('shouldComponentUpdate', () => {
      it('should update if the row data has changed', () => {
        const nextRows = testDataSource.rows().slice()
        nextRows[0] = ['new', 'row']
        const nextDataSource = testDataSource.setRows(nextRows)
        const row = renderRow()
        const shouldUpdate = row.instance().shouldComponentUpdate({...rowProps, tableDataSource: nextDataSource})
        expect(shouldUpdate).toBe(true)
      });

      it('should update if selection status for row has changed', () => {
        const nextSelection = {rowIdx: 2, colIdx: 0}
        const row = renderRow()
        const shouldUpdate = row.instance().shouldComponentUpdate({...rowProps, selection: nextSelection})
        expect(shouldUpdate).toBe(true)
      });

      it('should update even if row is still selected but selected cell has changed', () => {
        const nextSelection = {rowIdx: 1, colIdx: 1}
        const row = renderRow()
        const shouldUpdate = row.instance().shouldComponentUpdate({...rowProps, selection: nextSelection})
        expect(shouldUpdate).toBe(true)
      });

      it('should not update otherwise', () => {
        const nextRows = testDataSource.rows().slice()
        const nextDataSource = testDataSource.setRows(nextRows)
        const nextSelection = {...selection}
        const row = renderRow()
        const nextProps = {...rowProps, selection: nextSelection, tableDataSource: nextDataSource}
        const shouldUpdate = row.instance().shouldComponentUpdate(nextProps)
        expect(shouldUpdate).toBe(false)
      });
    });

    describe('isSelected', () => {
      it('returns true when selection matches props', () => {
        const row = renderRow()
        expect(row.instance().isSelected({
          selection: {rowIdx: 1},
          rowIdx: 1,
        })).toBe(true)
      });

      it('returns false otherwise', () => {
        const row = renderRow()
        expect(row.instance().isSelected({
          selection: {rowIdx: 2},
          rowIdx: 1,
        })).toBe(false)
      });
    });

    it('renders with the appropriate className when selected', () => {
      const row = renderRow()
      expect(row.hasClass('selected')).toBe(true)
    });

    it('renders with the appropriate className when not selected', () => {
      const row = renderRow({selection: {rowIdx: 2, colIdx: 0}})
      expect(row.hasClass('selected')).toBe(false)
    });

    it('renders any extra classNames', () => {
      const row = renderRow({className: 'my-row'})
      expect(row.hasClass('my-row')).toBe(true)
    });
  });

  describe('SelectableTable', () => {
    function renderTable(props) {
      return mount(
        <SelectableTable
          {...tableProps}
          {...props}
        />
      )
    }

    describe('onTab', () => {
      it('shifts selection to the next row if last column is selected', () => {
        const onShiftSelection = jasmine.createSpy('onShiftSelection')
        const table = renderTable({selection: {colIdx: 2, rowIdx: 1}, onShiftSelection})
        table.instance().onTab({key: 'Tab'})
        expect(onShiftSelection).toHaveBeenCalledWith({
          row: 1, col: -2, key: 'Tab',
        })
      });

      it('shifts selection to the next col otherwise', () => {
        const onShiftSelection = jasmine.createSpy('onShiftSelection')
        const table = renderTable({selection: {colIdx: 0, rowIdx: 1}, onShiftSelection})
        table.instance().onTab({key: 'Tab'})
        expect(onShiftSelection).toHaveBeenCalledWith({
          col: 1, key: 'Tab',
        })
      });
    });

    describe('onShiftTab', () => {
      it('shifts selection to the previous row if first column is selected', () => {
        const onShiftSelection = jasmine.createSpy('onShiftSelection')
        const table = renderTable({selection: {colIdx: 0, rowIdx: 2}, onShiftSelection})
        table.instance().onShiftTab({key: 'Tab'})
        expect(onShiftSelection).toHaveBeenCalledWith({
          row: -1, col: 2, key: 'Tab',
        })
      });

      it('shifts selection to the previous col otherwise', () => {
        const onShiftSelection = jasmine.createSpy('onShiftSelection')
        const table = renderTable({selection: {colIdx: 1, rowIdx: 1}, onShiftSelection})
        table.instance().onShiftTab({key: 'Tab'})
        expect(onShiftSelection).toHaveBeenCalledWith({
          col: -1, key: 'Tab',
        })
      });
    });

    it('renders with the correct props', () => {
      const RowRenderer = () => <tr />
      const CellRenderer = () => <td />
      const onSetSelection = () => {}
      const onShiftSelection = () => {}
      const extraProps = {p1: 'p1'}
      const table = renderTable({
        extraProps,
        onSetSelection,
        onShiftSelection,
        RowRenderer,
        CellRenderer,
      }).find(Table)
      expect(table.prop('extraProps')).toEqual({
        p1: 'p1',
        selection,
        onSetSelection,
        onShiftSelection,
      })
      expect(table.prop('tableDataSource')).toBe(testDataSource)
      expect(table.prop('RowRenderer')).toBe(RowRenderer)
      expect(table.prop('CellRenderer')).toBe(CellRenderer)
    });
  });
});
