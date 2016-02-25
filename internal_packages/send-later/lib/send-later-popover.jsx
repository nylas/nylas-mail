/** @babel */
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
      inputDate: null,
      scheduledDate: null,
    }
  }

  componentDidMount() {
    this._subscription = Rx.Observable.fromQuery(
      DatabaseStore.findBy(Message, {clientId: this.props.draftClientId})
    ).subscribe((draft)=> {
      const nextScheduledDate = SendLaterStore.getScheduledDateForMessage(draft);

      if (nextScheduledDate !== this.state.scheduledDate) {
        const isPopout = (NylasEnv.getWindowType() === "composer");
        const isFinishedSelecting = ((this.state.scheduledDate === 'saving') && (nextScheduledDate !== null));
        if (isPopout && isFinishedSelecting) {
          NylasEnv.close();
        }
        this.setState({scheduledDate: nextScheduledDate});
      }
    });
  }

  componentWillUnmount() {
    this._subscription.dispose();
  }

  onSelectMenuOption = (optionKey)=> {
    const date = SendLaterOptions[optionKey]();
    this.onSelectDate(date);
  };

  onSelectCustomOption = (value)=> {
    const date = DateUtils.futureDateFromString(value);
    if (date) {
      this.onSelectDate(date);
    } else {
      NylasEnv.showErrorDialog(`Sorry, we can't parse ${value} as a valid date.`);
    }
  };

  onSelectDate = (date)=> {
    const formatted = DateUtils.format(date.utc());
    SendLaterActions.sendLater(this.props.draftClientId, formatted);
    this.setState({scheduledDate: 'saving', inputDate: null});
    this.refs.popover.close();
  };

  onCancelSendLater = ()=> {
    SendLaterActions.cancelSendLater(this.props.draftClientId);
    this.setState({inputDate: null});
    this.refs.popover.close();
  };

  renderCustomTimeSection() {
    const onChange = (event)=> {
      this.setState({inputDate: DateUtils.futureDateFromString(event.target.value)});
    }

    const onKeyDown = (event)=> {
      // we need to swallow these events so they don't reach the menu
      // containing the text input, but only when you've typed something.
      const val = event.target.value;
      if ((val.length > 0) && ["Enter", "Return"].includes(event.key)) {
        this.onSelectCustomOption(val);
        event.stopPropagation();
      }
    };

    let dateInterpretation = false;
    if (this.state.inputDate) {
      dateInterpretation = (<span className="time">
        {DateUtils.format(this.state.inputDate, DATE_FORMAT_LONG)}
      </span>);
    }

    return (
      <div key="custom" className="custom-time-section">
        <input
          tabIndex="1"
          type="text"
          placeholder="Or, 'next Monday at 2PM'"
          onKeyDown={onKeyDown}
          onChange={onChange}/>
        {dateInterpretation}
      </div>
    )
  }

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

    let dateInterpretation = false;
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
        <Menu ref="menu"
              items={ Object.keys(SendLaterOptions) }
              itemKey={ (item)=> item }
              itemContent={this.renderMenuOption}
              defaultSelectedIndex={-1}
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
