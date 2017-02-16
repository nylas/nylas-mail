import React, {PropTypes} from 'react'
import classnames from 'classnames'
import {RetinaImg} from 'nylas-component-kit'
import {DataTransferTypes, DragBehaviors} from './mail-merge-constants'


function onDragStart(event, {draftClientId, colIdx, colName, dragBehavior}) {
  const {dataTransfer} = event
  dataTransfer.effectAllowed = 'move'
  dataTransfer.setData(DataTransferTypes.DraftId, draftClientId)
  dataTransfer.setData(DataTransferTypes.ColIdx, colIdx)
  dataTransfer.setData(DataTransferTypes.ColName, colName)
  dataTransfer.setData(DataTransferTypes.DragBehavior, dragBehavior)
}

function MailMergeToken(props) {
  const {draftClientId, colIdx, colName, children, draggable, dragBehavior} = props
  const classes = classnames({
    'mail-merge-token': true,
    [`token-color-${colIdx % 5}`]: true,
  })
  const _onDragStart = event => onDragStart(event, {draftClientId, colIdx, colName, dragBehavior})
  const dragHandle = draggable ? <RetinaImg name="mailmerge-grabber.png" mode={RetinaImg.Mode.ContentIsMask} /> : null;

  return (
    <span draggable={draggable} className={classes} onDragStart={_onDragStart}>
      {dragHandle}
      {children}
    </span>
  )
}
MailMergeToken.propTypes = {
  draftClientId: PropTypes.string,
  colIdx: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  colName: PropTypes.string,
  children: PropTypes.node,
  draggable: PropTypes.bool,
  dragBehavior: PropTypes.string,
}

MailMergeToken.defaultProps = {
  draggable: false,
  dragBehavior: DragBehaviors.Copy,
}

export default MailMergeToken
