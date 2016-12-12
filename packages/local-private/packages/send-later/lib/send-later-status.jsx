import React, {Component, PropTypes} from 'react'
import moment from 'moment'
import {DateUtils, Actions} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import {PLUGIN_ID} from './send-later-constants'

const {DATE_FORMAT_SHORT} = DateUtils


export default class SendLaterStatus extends Component {
  static displayName = 'SendLaterStatus';

  static propTypes = {
    draft: PropTypes.object,
  };

  onCancelSendLater = () => {
    Actions.setMetadata(this.props.draft, PLUGIN_ID, {sendLaterDate: null});
  };

  render() {
    const {draft} = this.props
    const metadata = draft.metadataForPluginId(PLUGIN_ID)
    if (metadata && metadata.sendLaterDate) {
      const {sendLaterDate} = metadata
      const formatted = DateUtils.format(moment(sendLaterDate), DATE_FORMAT_SHORT)
      return (
        <div className="send-later-status">
          <span className="time">
            {`Scheduled for ${formatted}`}
          </span>
          <RetinaImg
            name="image-cancel-button.png"
            title="Cancel Send Later"
            onClick={this.onCancelSendLater}
            mode={RetinaImg.Mode.ContentPreserve}
          />
        </div>
      )
    }
    return <span />
  }
}
