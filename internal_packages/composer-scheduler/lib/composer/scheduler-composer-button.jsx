import React from 'react'
import ReactDOM from 'react-dom'
import {
  Actions,
  APIError,
  NylasAPI,
} from 'nylas-exports'
import {Menu, RetinaImg} from 'nylas-component-kit'
import {PLUGIN_ID, PLUGIN_NAME} from '../scheduler-constants'

import NewEventHelper from './new-event-helper'

import moment from 'moment'
// moment-round upon require patches `moment` with new functions.
require('moment-round')

const MEETING_REQUEST = "Send a meeting request…"
const PROPOSAL = "Propose times to meet…"

export default class SchedulerComposerButton extends React.Component {
  static displayName = "SchedulerComposerButton";

  static propTypes = {
    draft: React.PropTypes.object.isRequired,
    session: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = {enabled: false};
    this._unsubscribes = [];
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (this.state !== nextState) ||
      (this._hasPendingEvent(nextProps) !== this._hasPendingEvent(this.props));
  }

  _hasPendingEvent(props) {
    const metadata = props.draft.metadataForPluginId(PLUGIN_ID);
    return metadata && metadata.pendingEvent
  }

  // Helper method that will render the contents of our popover.
  _renderPopover() {
    const headerComponents = [
      <span key="header">I'd like to:</span>,
    ];
    const items = [
      MEETING_REQUEST,
      PROPOSAL,
    ];
    const idFn = (item) => item
    return (
      <Menu
        className="scheduler-picker"
        items={items}
        itemKey={idFn}
        itemContent={idFn}
        headerComponents={headerComponents}
        defaultSelectedIndex={-1}
        onSelect={this._onSelectItem}
      />
    )
  }

  _onSelectItem = (item) => {
    NewEventHelper.addEventToSession(this.props.session)

    if (item === PROPOSAL) {
      NewEventHelper.launchCalendarWindow(this.props.draft.clientId)
    }
    Actions.closePopover()
  }

  _onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    NylasAPI.authPlugin(PLUGIN_ID, PLUGIN_NAME, this.props.draft.accountId)
    .catch((error) => {
      let title = "Error"
      let msg = `Unfortunately scheduling is not currently available. \
Please try again later.\n\nError: ${error}`
      if (!(error instanceof APIError)) {
        NylasEnv.reportError(error);
      } else if (error.statusCode === 400) {
        NylasEnv.reportError(error);
      } else if (NylasAPI.TimeoutErrorCodes.includes(error.statusCode)) {
        title = "Offline"
        msg = `Scheduling does not work offline. Please try again when you come back online.`
      }
      Actions.closePopover()
      NylasEnv.showErrorDialog({title, message: msg});
    });
    Actions.openPopover(
      this._renderPopover(),
      {originRect: buttonRect, direction: 'up'}
    )
  }

  _now() {
    return moment()
  }

  render() {
    const hasEvent = this._hasPendingEvent(this.props);
    return (
      <button className={`btn btn-toolbar ${hasEvent ? "btn-enabled" : ""}`}
        onClick={this._onClick}
        title="Schedule an event…"
      >
      <RetinaImg url="nylas://composer-scheduler/assets/ic-composer-scheduler@2x.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
      &nbsp;
      <RetinaImg
        name="icon-composer-dropdown.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    </button>)
  }
}

SchedulerComposerButton.containerRequired = false;
