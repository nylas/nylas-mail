import React, {PropTypes} from 'react'
import Toast from './toast'
import RetinaImg from './retina-img'


function UndoToast(props) {
  const {className, onUndo, undoMessage, ...toastProps} = props
  return (
    <Toast
      {...toastProps}
      className={`nylas-undo-toast ${className}`}
    >
      <div className="undo-message-wrapper">
        {undoMessage}
      </div>
      <div className="undo-action-wrapper" onClick={onUndo}>
        <RetinaImg
          name="undo-icon@2x.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
        <span className="undo-action-text">Undo</span>
      </div>
    </Toast>
  )
}

UndoToast.propTypes = {
  className: PropTypes.string,
  undoMessage: PropTypes.string,
  onUndo: PropTypes.func,
}

export default UndoToast
