/** @babel */
import Rx from 'rx-lite'
import React, {Component, PropTypes} from 'react'
import {DateUtils, Message, DatabaseStore} from 'nylas-exports'
import {Popover, RetinaImg, Menu, DateInput} from 'nylas-component-kit'
import SendLaterActions from './send-later-actions'
import {DATE_FORMAT_SHORT, DATE_FORMAT_LONG, PLUGIN_ID} from './send-later-constants'


const SendLaterOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'In 2 hours': DateUtils.in2Hours,
  'Later today': DateUtils.laterToday,
  'Tomorrow morning': DateUtils.tomorrow,
  'Tomorrow evening': DateUtils.tomorrowEvening,
  'This weekend': DateUtils.thisWeekend,
  'Next week': DateUtils.nextWeek,
}

class SendLaterPopover extends Component {
  static displayName = 'SendLaterPopover';

  static propTypes = {
    draftClientId: PropTypes.string.isRequired,
  };

  constructor(props) {
    super(props)
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

  onMessageChanged = (message)=> {
    if (!message) return;
    const messageMetadata = message.metadataForPluginId(PLUGIN_ID) || {}
    const nextScheduledDate = messageMetadata.sendLaterDate

    if (nextScheduledDate !== this.state.scheduledDate) {
      const isComposer = NylasEnv.isComposerWindow()
      const isFinishedSelecting = ((this.state.scheduledDate === 'saving') && (nextScheduledDate !== null));
      if (isComposer && isFinishedSelecting) {
        NylasEnv.close();
      }
      this.setState({scheduledDate: nextScheduledDate});
    }
  };

  onSelectMenuOption = (optionKey)=> {
    const date = SendLaterOptions[optionKey]();
    this.selectDate(date, optionKey);
  };

  onSelectCustomOption = (date, inputValue)=> {
    if (date) {
      this.selectDate(date, "Custom");
    } else {
      NylasEnv.showErrorDialog(`Sorry, we can't parse ${inputValue} as a valid date.`);
    }
  };

  onCancelSendLater = ()=> {
    SendLaterActions.cancelSendLater(this.props.draftClientId);
    this.refs.popover.close();
  };

  selectDate = (date, dateLabel)=> {
    const formatted = DateUtils.format(date.utc());
    SendLaterActions.sendLater(this.props.draftClientId, formatted, dateLabel);
    this.setState({scheduledDate: 'saving'});
    this.refs.popover.close();
  };

  renderMenuOption(optionKey) {
    const date = SendLaterOptions[optionKey]();
    const formatted = DateUtils.format(date, DATE_FORMAT_SHORT);
    return (
      <div className="send-later-option">{optionKey}<span className="time">{formatted}</span></div>
    );
  }

  renderButton() {
    const {scheduledDate} = this.state;
    let className = 'btn btn-toolbar btn-send-later';

    if (scheduledDate === 'saving') {
      return (
        <button className={className} title="Saving send date...">
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}/>
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
      <button className={className} title="Send later…">
        <RetinaImg name="icon-composer-sendlater.png" mode={RetinaImg.Mode.ContentIsMask}/>
        {dateInterpretation}
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }

  render() {
    const headerComponents = [
      <span>Send later:</span>,
    ]
    const footerComponents = [
      <div key="divider" className="divider" />,
      <DateInput
        key="custom"
        className="custom-section"
        dateFormat={DATE_FORMAT_LONG}
        onSubmitDate={this.onSelectCustomOption} />,
    ];

    if (this.state.scheduledDate) {
      footerComponents.push(<div key="divider-unschedule" className="divider" />)
      footerComponents.push(
        <div className="cancel-section" key="cancel-section">
          <button className="btn" onClick={this.onCancelSendLater}>
            Unschedule Send
          </button>
        </div>
      )
    }

    return (
      <Popover
        ref="popover"
        style={{order: -103}}
        className="send-later"
        buttonComponent={this.renderButton()}>
        <Menu ref="menu"
              items={ Object.keys(SendLaterOptions) }
              itemKey={ (item)=> item }
              itemContent={this.renderMenuOption}
              defaultSelectedIndex={-1}
              headerComponents={headerComponents}
              footerComponents={footerComponents}
              onSelect={this.onSelectMenuOption}
              />
      </Popover>
    );
  }

}

SendLaterPopover.containerStyles = {
  order: -99,
};

export default SendLaterPopover
