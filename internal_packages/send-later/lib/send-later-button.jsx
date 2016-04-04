/** @babel */
import Rx from 'rx-lite'
import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import {Actions, DateUtils, Message, DatabaseStore} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import SendLaterPopover from './send-later-popover'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID} from './send-later-constants'


class SendLaterButton extends Component {
  static displayName = 'SendLaterButton';

  static propTypes = {
    draftClientId: PropTypes.string.isRequired,
  };

  constructor() {
    super()
    this.state = {
      scheduledDate: null,
    }
  }

  componentDidMount() {
    this._subscription = Rx.Observable.fromQuery(
      DatabaseStore.findBy(Message, {clientId: this.props.draftClientId})
    ).subscribe(this.onMessageChanged);
  }

  componentWillUnmount() {
    this._subscription.dispose();
  }

  onSendLater = (formattedDate, dateLabel) => {
    SendLaterActions.sendLater(this.props.draftClientId, formattedDate, dateLabel);
    this.setState({scheduledDate: 'saving'});
  };

  onCancelSendLater = () => {
    SendLaterActions.cancelSendLater(this.props.draftClientId);
  };

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      <SendLaterPopover
        scheduledDate={this.state.scheduledDate}
        onSendLater={this.onSendLater}
        onCancelSendLater={this.onCancelSendLater}
      />,
      {originRect: buttonRect, direction: 'up'}
    )
  };

  onMessageChanged = (message) => {
    if (!message) return;
    const {scheduledDate} = this.state;
    const messageMetadata = message.metadataForPluginId(PLUGIN_ID) || {}
    const nextScheduledDate = messageMetadata.sendLaterDate

    if (nextScheduledDate !== scheduledDate) {
      const isComposer = NylasEnv.isComposerWindow()
      const isFinishedSelecting = ((scheduledDate === 'saving') && (nextScheduledDate !== null));
      if (isComposer && isFinishedSelecting) {
        NylasEnv.close();
      }
      this.setState({scheduledDate: nextScheduledDate});
    }
  };

  render() {
    const {scheduledDate} = this.state;
    let className = 'btn btn-toolbar btn-send-later';

    if (scheduledDate === 'saving') {
      return (
        <button className={className} title="Saving send date..." tabIndex={-1}>
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}
          />
        </button>
      );
    }

    let dateInterpretation;
    if (scheduledDate) {
      className += ' btn-enabled';
      const momentDate = DateUtils.futureDateFromString(scheduledDate);
      if (momentDate) {
        dateInterpretation = <span className="at">Sending in {momentDate.fromNow(true)}</span>;
      }
    }
    return (
      <button className={className} title="Send later…" onClick={this.onClick} tabIndex={-1}>
        <RetinaImg name="icon-composer-sendlater.png" mode={RetinaImg.Mode.ContentIsMask} />
        {dateInterpretation}
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}

SendLaterButton.containerStyles = {
  order: -99,
};

export default SendLaterButton;
