import React, {Component, PropTypes} from 'react'
import {Flexbox} from 'nylas-component-kit'
import {timestamp} from './formatting-utils'
import SendingProgressBar from './sending-progress-bar'
import SendingCancelButton from './sending-cancel-button'

export default class DraftListSendStatus extends Component {
  static displayName = 'DraftListSendStatus';

  static propTypes = {
    draft: PropTypes.object,
  };

  static containerRequired = false;

  render() {
    const {draft} = this.props
    if (draft.uploadTaskId) {
      return (
        <Flexbox style={{width: 150, whiteSpace: 'no-wrap'}}>
          <SendingProgressBar style={{flex: 1, marginRight: 10}} progress={draft.uploadProgress * 100} />
          <SendingCancelButton taskId={draft.uploadTaskId} />
        </Flexbox>
      )
    }
    return <span className="timestamp">{timestamp(draft.date)}</span>
  }
}
