import React, {PropTypes} from 'react'
import {EditableTable} from 'nylas-component-kit'
import {pickHTMLProps} from 'pick-react-known-prop'
import MailMergeHeaderInput from './mail-merge-header-input'


function InputRenderer(props) {
  const {isHeader, draftClientId} = props;
  if (!isHeader) {
    return <input {...pickHTMLProps(props)} defaultValue={props.defaultValue} />
  }
  return <MailMergeHeaderInput draftClientId={draftClientId} {...props} />
}
InputRenderer.propTypes = {
  isHeader: PropTypes.bool,
  defaultValue: PropTypes.string,
  draftClientId: PropTypes.string,
}

function MailMergeTable(props) {
  const {draftClientId} = props
  return (
    <div className="mail-merge-table">
      <EditableTable
        {...props}
        displayHeader
        displayNumbers
        rowHeight={30}
        bodyHeight={150}
        inputProps={{draftClientId}}
        InputRenderer={InputRenderer}
      />
    </div>
  )
}
MailMergeTable.propTypes = {
  tableDataSource: EditableTable.propTypes.tableDataSource,
  selection: PropTypes.object,
  draftClientId: PropTypes.string,
  onShiftSelection: PropTypes.func,
}

export default MailMergeTable
