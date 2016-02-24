/** @babel */
import _ from 'underscore'
import Rx from 'rx-lite'
import React, {Component, PropTypes} from 'react'
import {DateUtils, Message, DatabaseStore} from 'nylas-exports'
import {Popover, RetinaImg, Menu} from 'nylas-component-kit'
import SendLaterActions from './send-later-actions'
import SendLaterStore from './send-later-store'
import {DATE_FORMAT_SHORT, DATE_FORMAT_LONG} from './send-later-constants'


const SendLaterOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'In 2 hours': DateUtils.in2Hours,
  'Later Today': DateUtils.laterToday,
  'Tomorrow Morning': DateUtils.tomorrow,
  'Tomorrow Evening': DateUtils.tomorrowEvening,
  'This Weekend': DateUtils.thisWeekend,
  'Next Week': DateUtils.nextWeek,
}

class SendLaterPopover extends Component {
  static displayName = 'SendLaterPopover';

  static propTypes = {
    draftClientId: PropTypes.string,
  };

  constructor(props) {
    super(props)
    this.state = {
      inputDate: null,
      scheduledDate: null,
    }
  }

  componentDidMount() {
    this._subscription = Rx.Observable.fromQuery(
      DatabaseStore.findBy(Message, {clientId: this.props.draftClientId})
    ).subscribe((draft)=> {
      const scheduledDate = SendLaterStore.getScheduledDateForMessage(draft);
      if (scheduledDate !== this.state.scheduledDate) {
        this.setState({scheduledDate});
      }
    });
  }

  componentWillUnmount() {
    this._subscription.dispose();
  }

  onSelectMenuOption = (optionKey)=> {
    const date = SendLaterOptions[optionKey]();
    const formatted = DateUtils.format(date.utc())

    SendLaterActions.sendLater(this.props.draftClientId, formatted)
    this.setState({scheduledDate: 'saving', inputDate: null})
    this.refs.popover.close()
  };

  onCancelSendLater = ()=> {
    SendLaterActions.cancelSendLater(this.props.draftClientId)
    this.setState({inputDate: null})
    this.refs.popover.close()
  };

  renderCustomTimeSection() {
    const updateInputDateValue = _.debounce((value)=> {
      this.setState({inputDate: DateUtils.fromString(value)})
    }, 250);

    let dateInterpretation = false;
    if (this.state.inputDate) {
      dateInterpretation = (<em>
        {DateUtils.format(this.state.inputDate, DATE_FORMAT_LONG)}
      </em>);
    }

    return (
      <div key="custom" className="custom-time-section">
        <input
          tabIndex="1"
          type="text"
          placeholder="Or, 'next monday at 2PM'"
          onChange={event=> updateInputDateValue(event.target.value)}/>
        {dateInterpretation}
      </div>
    )
  }

  renderMenuOption(optionKey) {
    const date = SendLaterOptions[optionKey]();
    const formatted = DateUtils.format(date, DATE_FORMAT_SHORT);
    return (
      <div className="send-later-option">{optionKey}<em>{formatted}</em></div>
    );
  }

  renderButton() {
    const {scheduledDate} = this.state;
    let className = 'btn btn-toolbar btn-send-later';

    if (scheduledDate === 'saving') {
      return (
        <button className={className} title="Send later...">
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}/>
        </button>
      );
    }

    let dateInterpretation = false;
    if (scheduledDate) {
      className += ' btn-enabled';
      const momentDate = DateUtils.fromString(scheduledDate);
      if (momentDate) {
        dateInterpretation = <span className="at">Sending in {momentDate.fromNow(true)}</span>;
      }
    }
    return (
      <button className={className}>
        <RetinaImg name="icon-composer-sendlater.png" mode={RetinaImg.Mode.ContentIsMask}/>
        {dateInterpretation}
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </button>
    );
  }

  render() {
    const footerComponents = [
      <div key="divider" className="divider" />,
      this.renderCustomTimeSection(),
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
        <Menu items={ Object.keys(SendLaterOptions) }
              itemKey={ (item)=> item }
              itemContent={this.renderMenuOption}
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
