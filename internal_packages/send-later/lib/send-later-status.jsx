import React, {Component, PropTypes} from 'react'
import moment from 'moment'
import {DateUtils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID, DATE_FORMAT_SHORT} from './send-later-constants'

export default class SendLaterStatus extends Component {
  static displayName = 'SendLaterStatus';

  static propTypes = {
    draft: PropTypes.object,
  };

  onCancelSendLater = ()=> {
    SendLaterActions.cancelSendLater(this.props.draft.clientId)
  };

  render() {
    const {draft} = this.props
    const metadata = draft.metadataForPluginId(PLUGIN_ID)
    if (metadata && metadata.sendLaterDate) {
      const {sendLaterDate} = metadata
      const formatted = DateUtils.format(moment(sendLaterDate), DATE_FORMAT_SHORT)
      return (
        <div className="send-later-status">
          <em className="send-later-status">
            {`Scheduled for ${formatted}`}
          </em>
          <RetinaImg
            name="image-cancel-button.png"
            title="Cancel Send Later"
            onClick={this.onCancelSendLater}
            mode={RetinaImg.Mode.ContentPreserve} />
        </div>
      )
    }
    return <span />
  }
}
