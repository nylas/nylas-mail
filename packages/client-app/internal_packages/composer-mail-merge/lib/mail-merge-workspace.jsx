import React, {Component, PropTypes} from 'react'
import {RetinaImg, DropZone} from 'nylas-component-kit'
import fs from 'fs';

import {parseCSV} from './mail-merge-utils'
import MailMergeTable from './mail-merge-table'


class MailMergeWorkspace extends Component {
  static displayName = 'MailMergeWorkspace'

  static propTypes = {
    isWorkspaceOpen: PropTypes.bool,
    tableDataSource: MailMergeTable.propTypes.tableDataSource,
    selection: PropTypes.object,
    draftClientId: PropTypes.string,
    session: PropTypes.object,
  }

  constructor() {
    super()
    this.state = {isDropping: false}
  }

  onDragStateChange = ({isDropping}) => {
    this.setState({isDropping})
  }

  onChooseCSV = () => {
    NylasEnv.showOpenDialog({
      properties: ['openFile'],
      filters: [
        { name: 'CSV Files', extensions: ['csv', 'txt'] },
      ],
    }, (pathsToOpen) => {
      if (!pathsToOpen || pathsToOpen.length === 0) {
        return;
      }

      fs.readFile(pathsToOpen[0], (err, contents) => {
        parseCSV(contents.toString()).then((tableData) => {
          this.loadCSV(tableData)
        });
      });
    });
  }

  onDropCSV = (event) => {
    event.stopPropagation()
    const {dataTransfer} = event
    const file = dataTransfer.files[0]
    parseCSV(file)
    .then(tableData => this.loadCSV(tableData))
  }

  loadCSV(newTableData) {
    const {tableDataSource, session} = this.props
    // TODO We need to reset the table values first because `EditableTable` does
    // not support controlled inputs, i.e. the inputs just use the
    // defaultValue props which will only apply when the input is empty
    session.clearTableData()
    session.loadTableData({newTableData, prevColumns: tableDataSource.columns()})
  }

  shouldAcceptDrop = (event) => {
    event.stopPropagation()
    const {dataTransfer} = event
    if (dataTransfer.files.length === 1) {
      const file = dataTransfer.files[0]
      if (file.type === 'text/csv') {
        return true
      }
    }
    return false
  }

  renderSelectionControls() {
    const {selection, tableDataSource, session} = this.props
    const rows = tableDataSource.rows()
    return (
      <div className="selection-controls">
        <div className="btn btn-group">
          <div
            className="btn-prev"
            onClick={() => session.shiftSelection({row: -1})}
          >
            <RetinaImg
              name="toolbar-dropdown-chevron.png"
              mode={RetinaImg.Mode.ContentIsMask}
            />
          </div>
          <div
            className="btn-next"
            onClick={() => session.shiftSelection({row: 1})}
          >
            <RetinaImg
              name="toolbar-dropdown-chevron.png"
              mode={RetinaImg.Mode.ContentIsMask}
            />
          </div>
        </div>
        <span>Recipient {selection.rowIdx + 1} of {rows.length}</span>
        <span style={{flex: 1}} />
        <div className="btn" onClick={this.onChooseCSV}>
          Import CSV
        </div>
      </div>
    )
  }

  renderDropCover() {
    const {isDropping} = this.state
    const display = isDropping ? 'block' : 'none';
    return (
      <div className="composer-drop-cover" style={{display}}>
        <div className="centered">
          Drop to Import CSV
        </div>
      </div>
    )
  }

  render() {
    const {session, draftClientId, isWorkspaceOpen, tableDataSource, selection, ...otherProps} = this.props
    if (!isWorkspaceOpen) {
      return false
    }

    return (
      <DropZone
        className="mail-merge-workspace"
        onDrop={this.onDropCSV}
        shouldAcceptDrop={this.shouldAcceptDrop}
        onDragStateChange={this.onDragStateChange}
      >
        <style>
          {".btn-send-later { display:none; }"}
        </style>
        {this.renderDropCover()}
        {this.renderSelectionControls()}
        <MailMergeTable
          {...otherProps}
          selection={selection}
          tableDataSource={tableDataSource}
          draftClientId={draftClientId}
          onCellEdited={session.updateCell}
          onSetSelection={session.setSelection}
          onShiftSelection={session.shiftSelection}
          onAddColumn={session.addColumn}
          onRemoveColumn={session.removeLastColumn}
          onAddRow={session.addRow}
          onRemoveRow={session.removeRow}
        />
      </DropZone>
    )
  }
}

export default MailMergeWorkspace
