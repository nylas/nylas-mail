import React, {PropTypes} from 'react'
import {Actions} from 'nylas-exports'
import {KeyCommandsRegion, UndoToast, ListensToFluxStore} from 'nylas-component-kit'
import UndoSendStore from './undo-send-store'


function UndoSendToast(props) {
  const {visible, sendActionTaskId} = props
  return (
    <KeyCommandsRegion
      globalHandlers={{
        'core:undo': (event) => {
          if (!visible) { return }
          event.preventDefault();
          event.stopPropagation();
          Actions.dequeueTask(sendActionTaskId)
        },
      }}
    >
      <UndoToast
        {...props}
        className="undo-send-toast"
        undoMessage="Sending draft"
        visibleDuration={null}
        onUndo={() => Actions.dequeueTask(sendActionTaskId)}
      />
    </KeyCommandsRegion>
  )
}
UndoSendToast.displayName = 'UndoSendToast'
UndoSendToast.propTypes = {
  visible: PropTypes.bool,
  sendActionTaskId: PropTypes.string,
}

export default ListensToFluxStore(UndoSendToast, {
  stores: [UndoSendStore],
  getStateFromStores() {
    return {
      visible: UndoSendStore.shouldShowUndoSend(),
      sendActionTaskId: UndoSendStore.sendActionTaskId(),
    }
  },
})

