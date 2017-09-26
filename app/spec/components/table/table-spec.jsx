import React from 'react'
import {shallow} from 'enzyme'
import {Table, TableRow, TableCell, LazyRenderedList} from 'mailspring-component-kit'
import {testDataSource} from '../../fixtures/table-data'


describe('Table Components', function describeBlock() {
  describe('TableCell', () => {
    it('renders children correctly', () => {
      const element = shallow(<TableCell>Cell</TableCell>)
      expect(element.text()).toEqual('Cell')
    });

    it('renders a th when is header', () => {
      const element = shallow(<TableCell isHeader />)
      expect(element.type()).toEqual('th')
    });

    it('renders a td when is not header', () => {
      const element = shallow(<TableCell isHeader={false} />)
      expect(element.type()).toEqual('td')
    });

    it('renders extra classNames', () => {
      const element = shallow(<TableCell className="my-cell" />)
      expect(element.hasClass('my-cell')).toBe(true)
    });

    it('passes additional props to cell', () => {
      const handler = () => {}
      const element = shallow(<TableCell className="my-cell" onClick={handler} />)
      expect(element.prop('onClick')).toBe(handler)
    });
  });

  describe('TableRow', () => {
    function renderRow(props = {}) {
      return shallow(
        <TableRow
          rowIdx={0}
          tableDataSource={testDataSource}
          {...props}
        />
      )
    }

    it('renders extra classNames', () => {
      const row = renderRow({className: 'my-row'})
      expect(row.hasClass('my-row')).toBe(true)
    });

    it('renders correct className when row is header', () => {
      const row = renderRow({isHeader: true})
      expect(row.hasClass('table-row-header')).toBe(true)
    });

    it('renders cells correctly given the tableDataSource', () => {
      const row = renderRow()
      expect(row.children().length).toBe(3)
      row.children().forEach((cell, idx) => {
        expect(cell.type()).toBe(TableCell)
        expect(cell.childAt(0).text()).toEqual(`${idx + 1}`)
      })
    });

    it('renders cells correctly if row is header', () => {
      const row = renderRow({isHeader: true, rowIdx: null})
      expect(row.children().length).toBe(3)
      row.children().forEach((cell, idx) => {
        expect(cell.type()).toBe(TableCell)
        expect(cell.childAt(0).text()).toEqual(`col${idx + 1}`)
      })
    });

    it('renders an empty first cell if displayNumbers is specified and is header', () => {
      const row = renderRow({displayNumbers: true, isHeader: true, rowIdx: null})
      const cell = row.childAt(0)
      expect(row.children().length).toBe(4)
      expect(cell.type()).toBe(TableCell)
      expect(cell.hasClass('numbered-cell')).toBe(true)
      expect(cell.childAt(0).text()).toEqual('')
    });

    it('renders first cell with row number if displayNumbers specified', () => {
      const row = renderRow({displayNumbers: true})
      expect(row.children().length).toBe(4)

      const cell = row.childAt(0)
      expect(cell.type()).toBe(TableCell)
      expect(cell.hasClass('numbered-cell')).toBe(true)
      expect(cell.childAt(0).text()).toEqual('1')
    });

    it('renders cell correctly given the CellRenderer', () => {
      const CellRenderer = (props) => <div {...props} />
      const row = renderRow({CellRenderer})
      expect(row.children().length).toBe(3)
      row.children().forEach((cell) => {
        expect(cell.type()).toBe(CellRenderer)
      })
    });

    it('passes correct props to children cells', () => {
      const extraProps = {prop1: 'prop1'}
      const row = renderRow({extraProps})
      expect(row.children().length).toBe(3)
      row.children().forEach((cell, idx) => {
        expect(cell.type()).toBe(TableCell)
        expect(cell.prop('rowIdx')).toEqual(0)
        expect(cell.prop('colIdx')).toEqual(idx)
        expect(cell.prop('prop1')).toEqual('prop1')
        expect(cell.prop('tableDataSource')).toBe(testDataSource)
      })
    });
  });

  describe('Table', () => {
    function renderTable(props = {}) {
      return shallow(<Table {...props} tableDataSource={testDataSource} />)
    }

    it('renders extra classNames', () => {
      const table = renderTable({className: 'my-table'})
      expect(table.hasClass('nylas-table')).toBe(true)
      expect(table.hasClass('my-table')).toBe(true)
    });

    describe('renderHeader', () => {
      it('renders nothing if displayHeader is not specified', () => {
        const table = renderTable({displayHeader: false})
        expect(table.find('thead').length).toBe(0)
      });

      it('renders header row with the given RowRenderer', () => {
        const RowRenderer = (props) => <div {...props} />
        const table = renderTable({displayHeader: true, RowRenderer})
        const header = table.find('thead').childAt(0)
        expect(header.type()).toBe(RowRenderer)
      });

      it('passes correct props to header row', () => {
        const table = renderTable({displayHeader: true, displayNumbers: true, extraProps: {p1: 'p1'}})
        const header = table.find('thead').childAt(0)
        expect(header.type()).toBe(TableRow)
        expect(header.prop('rowIdx')).toBe(null)
        expect(header.prop('tableDataSource')).toBe(testDataSource)
        expect(header.prop('displayNumbers')).toBe(true)
        expect(header.prop('isHeader')).toBe(true)
        expect(header.prop('p1')).toEqual('p1')
        expect(header.prop('extraProps')).toEqual({isHeader: true, p1: 'p1'})
      });
    });

    describe('renderBody', () => {
      it('renders a lazy list with correct rows when header should not be displayed', () => {
        const table = renderTable()
        const body = table.find(LazyRenderedList)
        expect(body.prop('items')).toEqual(testDataSource.rows())
        expect(body.prop('BufferTag')).toEqual('tr')
        expect(body.prop('RootRenderer')).toEqual('tbody')
      });
    });

    describe('renderRow', () => {
      it('renders row with the given RowRenderer', () => {
        const RowRenderer = (props) => <div {...props} />
        const table = renderTable({RowRenderer})
        const Renderer = table.instance().renderRow
        const row = shallow(<Renderer idx={5} />)
        expect(row.type()).toBe(RowRenderer)
      });

      it('passes the correct props to the row when displayHeader is true', () => {
        const CellRenderer = (props) => <div {...props} />
        const extraProps = {p1: 'p1'}
        const table = renderTable({displayHeader: true, displayNumbers: true, extraProps, CellRenderer})
        const Renderer = table.instance().renderRow
        const row = shallow(<Renderer idx={5} />)
        expect(row.prop('p1')).toEqual('p1')
        expect(row.prop('rowIdx')).toBe(5)
        expect(row.prop('displayNumbers')).toBe(true)
        expect(row.prop('tableDataSource')).toBe(testDataSource)
        expect(row.prop('extraProps')).toBe(extraProps)
        expect(row.prop('CellRenderer')).toBe(CellRenderer)
      });

      it('passes the correct props to the row when displayHeader is false', () => {
        const table = renderTable({displayHeader: false})
        const Renderer = table.instance().renderRow
        const row = shallow(<Renderer idx={5} />)
        expect(row.prop('rowIdx')).toBe(5)
      });
    });
  });
});
