/** @babel */
import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import {Actions, DateUtils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import SendLaterPopover from './send-later-popover'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID} from './send-later-constants'


export default class SendLaterButton extends Component {
  static displayName = 'SendLaterButton';

  static propTypes = {
    draft: PropTypes.object.isRequired,
  };

  constructor() {
    super();

    this.state = {
      saving: false,
    };
  }

  componentWillReceiveProps(nextProps) {
    const isComposer = NylasEnv.isComposerWindow();
    const next = this._sendLaterDateForDraft(nextProps.draft);
    const isFinishedSelecting = ((this.state.saving) && (next !== null));
    if (isFinishedSelecting) {
      this.setState({saving: false});
      if (isComposer) {
        NylasEnv.close();
      }
    }
  }

  shouldComponentUpdate(nextProps, nextState) {
    if (nextState !== this.state) {
      return true;
    }
    if (this._sendLaterDateForDraft(nextProps.draft) !== this._sendLaterDateForDraft(this.props.draft)) {
      return true;
    }
    return false;
  }

  onSendLater = (formattedDate, dateLabel) => {
    SendLaterActions.sendLater(this.props.draft.clientId, formattedDate, dateLabel);
    this.setState({saving: true});
  };

  onCancelSendLater = () => {
    SendLaterActions.cancelSendLater(this.props.draft.clientId);
    Actions.closePopover();
  };

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      <SendLaterPopover
        sendLaterDate={this._sendLaterDateForDraft(this.props.draft)}
        onSendLater={this.onSendLater}
        onCancelSendLater={this.onCancelSendLater}
      />,
      {originRect: buttonRect, direction: 'up'}
    )
  };

  _sendLaterDateForDraft(draft) {
    if (!draft) {
      return null;
    }
    const messageMetadata = draft.metadataForPluginId(PLUGIN_ID) || {};
    return messageMetadata.sendLaterDate;
  }

  render() {
    let className = 'btn btn-toolbar btn-send-later';

    if (this.state.saving) {
      return (
        <button className={className} title="Saving send date..." tabIndex={-1} style={{order: -99}}>
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}
          />
        </button>
      );
    }

    let sendLaterLabel = false;
    const sendLaterDate = this._sendLaterDateForDraft(this.props.draft);

    if (sendLaterDate) {
      className += ' btn-enabled';
      const momentDate = DateUtils.futureDateFromString(sendLaterDate);
      if (momentDate) {
        sendLaterLabel = <span className="at">Sending in {momentDate.fromNow(true)}</span>;
      }
    }
    return (
      <button className={className} title="Send later…" onClick={this.onClick} tabIndex={-1} style={{order: -99}}>
        <RetinaImg name="icon-composer-sendlater.png" mode={RetinaImg.Mode.ContentIsMask} />
        {sendLaterLabel}
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}

SendLaterButton.containerRequired = false
