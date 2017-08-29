import React from 'react'
import PropTypes from 'prop-types'
import {Actions} from 'nylas-exports'
import {KeyCommandsRegion, UndoToast, ListensToFluxStore} from 'nylas-component-kit'
import UndoSendStore from './undo-send-store'


class UndoSendToast extends React.Component {
  static displayName = 'UndoSendToast';

  static propTypes = {
    visible: PropTypes.bool,
    sendActionTaskId: PropTypes.string,
  }

  _onUndo = () => {
    Actions.cancelTask(this.props.sendActionTaskId);
  }

  render() {
    const {visible} = this.props;
    return (
      <KeyCommandsRegion
        globalHandlers={{
          'core:undo': (event) => {
            if (!visible) { return }
            event.preventDefault();
            event.stopPropagation();
            this._onUndo();
          },
        }}
      >
        <UndoToast
          {...this.props}
          className="undo-send-toast"
          undoMessage="Sending draft"
          visibleDuration={null}
          onUndo={this._onUndo}
        />
      </KeyCommandsRegion>
    )
  }
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

