import React from 'react'
import {Utils} from 'nylas-exports'
import {NylasCalendar} from 'nylas-component-kit'
import SchedulerActions from '../scheduler-actions'
import ProposedTimeCalendarStore from '../proposed-time-calendar-store'
import ProposedTimeCalendarDataSource from './proposed-time-calendar-data-source'

/**
 * A an extended NylasCalendar that lets you pick proposed times.
 */
export default class ProposedTimePicker extends React.Component {
  static displayName = "ProposedTimePicker";

  constructor(props) {
    super(props);
    this.state = {
      duration: ProposedTimeCalendarStore.currentDuration(),
      pendingSave: ProposedTimeCalendarStore.pendingSave(),
    }
  }

  componentDidMount() {
    this._usub = ProposedTimeCalendarStore.listen(() => {
      this.setState({
        duration: ProposedTimeCalendarStore.currentDuration(),
        pendingSave: ProposedTimeCalendarStore.pendingSave(),
      });
    })
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
  }

  componentWillUnmount() {
    this._usub()
  }

  static containerStyles = {
    height: "100%",
  }

  _dataSource() {
    return new ProposedTimeCalendarDataSource()
  }

  _footerComponents = () => {
    return {
      week: [this._leftFooterComponents(), this._rightFooterComponents()],
    }
  }

  _leftFooterComponents() {
    const optComponents = ProposedTimeCalendarStore.DURATIONS.map((opt, i) => {
      return <option value={opt.join("|")} key={i}>{opt[2]}</option>
    })

    return (
      <div key="dp" className="duration-picker" style={{order: -100}}>
        <label style={{paddingRight: 10}}>Event Duration:</label>
        <select value={this.state.duration.join("|")} onChange={this._onChangeDuration}>
          {optComponents}
        </select>
      </div>
    );
  }

  _rightFooterComponents() {
    return (
      <button key="done"
        style={{order: 100}}
        onClick={this._onDone}
        className="btn btn-emphasis"
        disabled={this.state.pendingSave}
      >
        Done
      </button>
    );
  }

  _onChangeDuration = (event) => {
    SchedulerActions.changeDuration(event.target.value.split(","))
  }

  _onDone = () => {
    const proposals = ProposedTimeCalendarStore.timeBlocksAsProposals();
    // NOTE: This gets dispatched to the main window
    const {draftClientId} = NylasEnv.getWindowProps()
    SchedulerActions.confirmChoices({proposals, draftClientId});
    // Make sure the action gets to the main window then close this one.
    setTimeout(() => { NylasEnv.close() }, 10)
  }

  _onCalendarMouseUp({time, currentView}) {
    if (!time || currentView !== NylasCalendar.WEEK_VIEW) { return }
    SchedulerActions.addProposedTime(time);
    return
  }

  _onCalendarMouseMove({time, mouseIsDown, currentView}) {
    if (!time || !mouseIsDown || currentView !== NylasCalendar.WEEK_VIEW) { return }
    SchedulerActions.addProposedTime(time);
    return
  }

  _onCalendarMouseDown({time, currentView}) {
    if (!time || currentView !== NylasCalendar.WEEK_VIEW) { return }
    SchedulerActions.addProposedTime(time);
    return
  }

  render() {
    return (
      <NylasCalendar
        dataSource={this._dataSource()}
        footerComponents={this._footerComponents()}
        onCalendarMouseUp={this._onCalendarMouseUp}
        onCalendarMouseDown={this._onCalendarMouseDown}
        onCalendarMouseMove={this._onCalendarMouseMove}
      />
    )
  }
}
