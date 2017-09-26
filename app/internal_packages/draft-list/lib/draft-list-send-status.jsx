import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { DateUtils } from 'mailspring-exports';
import { Flexbox } from 'mailspring-component-kit';
import SendingProgressBar from './sending-progress-bar';

export default class DraftListSendStatus extends Component {
  static displayName = 'DraftListSendStatus';

  static propTypes = {
    draft: PropTypes.object,
  };

  static containerRequired = false;

  render() {
    const { draft } = this.props;
    if (draft.uploadTaskId) {
      return (
        <Flexbox style={{ width: 150, whiteSpace: 'nowrap' }}>
          <SendingProgressBar
            style={{ flex: 1, marginRight: 10 }}
            progress={draft.uploadProgress * 100}
          />
        </Flexbox>
      );
    }
    return <span className="timestamp">{DateUtils.shortTimeString(draft.date)}</span>;
  }
}
