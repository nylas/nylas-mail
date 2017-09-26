import React, {Component} from 'react'
import PropTypes from 'prop-types'
import ReactDOM from 'react-dom'
import moment from 'moment'
import {Actions, NylasAPIHelpers, FeatureUsageStore} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'

import SendLaterPopover from './send-later-popover'
import {PLUGIN_ID, PLUGIN_NAME} from './send-later-constants'

function sendLaterDateForDraft(draft) {
  return (draft && draft.metadataForPluginId(PLUGIN_ID) || {}).expiration;
}

class SendLaterButton extends Component {
  static displayName = 'SendLaterButton';

  static containerRequired = false;

  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
    isValidDraft: PropTypes.func,
  };

  constructor() {
    super();
    this.state = {
      saving: false,
    };
  }

  componentDidMount() {
    this.mounted = true;
  }

  shouldComponentUpdate(nextProps, nextState) {
    if (nextState.saving !== this.state.saving) {
      return true;
    }
    if (sendLaterDateForDraft(nextProps.draft) !== sendLaterDateForDraft(this.props.draft)) {
      return true;
    }
    return false;
  }

  componentWillUnmount() {
    this.mounted = false;
  }

  onAssignSendLaterDate = async (sendLaterDate, dateLabel) => {
    if (!this.props.isValidDraft()) { return }
    Actions.closePopover();

    const currentSendLaterDate = sendLaterDateForDraft(this.props.draft)
    if (currentSendLaterDate === sendLaterDate) { return }

    // Only check for feature usage and record metrics if this draft is not
    // already set to send later.
    if (!currentSendLaterDate) {
      try {
        await FeatureUsageStore.asyncUseFeature('send-later', {
          usedUpHeader: "All Scheduled Sends Used",
          usagePhrase: "schedule sending of",
          iconUrl: "mailspring://send-later/assets/ic-send-later-modal@2x.png",
        })
      } catch (error) {
        if (error instanceof FeatureUsageStore.NoProAccessError) {
          return
        }
      }

      this.setState({saving: true});
      const sendInSec = Math.round(((new Date(sendLaterDate)).valueOf() - Date.now()) / 1000)
      Actions.recordUserEvent("Draft Send Later", {
        timeInSec: sendInSec,
        timeInLog10Sec: Math.log10(sendInSec),
        label: dateLabel,
      });
    }
    this.onSetMetadata({expiration: sendLaterDate});
  };

  onCancelSendLater = () => {
    Actions.closePopover();
    this.onSetMetadata({expiration: null});
  };

  onSetMetadata = async ({expiration}) => {
    const {draft, session} = this.props;

    if (!this.mounted) { return; }
    this.setState({saving: true});

    try {
      await NylasAPIHelpers.authPlugin(PLUGIN_ID, PLUGIN_NAME, draft.accountId);
      if (!this.mounted) { return; }

      session.changes.addPluginMetadata(PLUGIN_ID, {expiration});

      if (expiration && NylasEnv.isComposerWindow()) {
        NylasEnv.close();
      }
    } catch (error) {
      NylasEnv.reportError(error);
      NylasEnv.showErrorDialog(`Sorry, we were unable to schedule this message. ${error.message}`);
    }

    if (!this.mounted) { return }
    this.setState({saving: false})
  }

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      <SendLaterPopover
        sendLaterDate={sendLaterDateForDraft(this.props.draft)}
        onAssignSendLaterDate={this.onAssignSendLaterDate}
        onCancelSendLater={this.onCancelSendLater}
      />,
      {originRect: buttonRect, direction: 'up'}
    )
  };

  render() {
    let className = 'btn btn-toolbar btn-send-later';

    if (this.state.saving) {
      return (
        <button
          className={className}
          title="Saving send date..."
          tabIndex={-1}
          style={{order: -99}}
        >
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}
          />
        </button>
      );
    }

    let sendLaterLabel = false;
    const sendLaterDate = sendLaterDateForDraft(this.props.draft);

    if (sendLaterDate) {
      className += ' btn-enabled';
      if (sendLaterDate > new Date()) {
        sendLaterLabel = <span className="at">Sending in {moment(sendLaterDate).fromNow(true)}</span>;
      } else {
        sendLaterLabel = <span className="at">Sending now</span>;
      }
    }
    return (
      <button
        className={className}
        title="Send later…"
        onClick={this.onClick}
        tabIndex={-1}
        style={{order: -99}}
      >
        <RetinaImg name="icon-composer-sendlater.png" mode={RetinaImg.Mode.ContentIsMask} />
        {sendLaterLabel}
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}

export default SendLaterButton
