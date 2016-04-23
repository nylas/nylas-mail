import React, {Component, PropTypes} from 'react'
import MailMergeTable from './mail-merge-table'


class MailMergeWorkspace extends Component {
  static displayName = 'MailMergeWorkspace'

  static propTypes = {
    isWorkspaceOpen: PropTypes.bool,
    tableData: MailMergeTable.propTypes.tableData,
    selection: PropTypes.object,
    draftClientId: PropTypes.string,
    session: PropTypes.object,
  }

  render() {
    const {session, draftClientId, isWorkspaceOpen, tableData, selection, ...otherProps} = this.props
    if (!isWorkspaceOpen) {
      return false
    }

    const {row} = selection
    const {rows} = tableData
    return (
      <div className="mail-merge-workspace">
        <div className="selection-controls">
          Recipient
          <span>
            <span onClick={()=> session.shiftSelection({row: -1})}>{'<'}</span>
            {row}
            <span onClick={()=> session.shiftSelection({row: 1})}>{'>'}</span>
          </span>
          of {rows.length - 1}
        </div>
        <MailMergeTable
          {...otherProps}
          selection={selection}
          tableData={tableData}
          draftClientId={draftClientId}
          onCellEdited={session.updateCell}
          onSetSelection={session.setSelection}
          onShiftSelection={session.shiftSelection}
          onAddColumn={session.addColumn}
          onRemoveColumn={session.removeColumn}
          onAddRow={session.addRow}
          onRemoveRow={session.removeRow}
        />
      </div>
    )
  }
}

export default MailMergeWorkspace
