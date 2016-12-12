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

  static containerStyles = {
    height: "100%",
  }

  constructor(props) {
    super(props);
    this.state = {
      proposals: ProposedTimeCalendarStore.proposals(),
      duration: ProposedTimeCalendarStore.currentDuration(),
      pendingSave: ProposedTimeCalendarStore.pendingSave(),
    }
  }

  componentDidMount() {
    this._usub = ProposedTimeCalendarStore.listen(() => {
      this.setState({
        duration: ProposedTimeCalendarStore.currentDuration(),
        proposals: ProposedTimeCalendarStore.proposals(),
        pendingSave: ProposedTimeCalendarStore.pendingSave(),
      });
    })
    NylasEnv.displayWindow()
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
  }

  componentWillUnmount() {
    this._usub()
  }

  _dataSource() {
    return new ProposedTimeCalendarDataSource()
  }

  _bannerComponents = () => {
    return {
      week: "Click and drag to propose times.",
    }
  }

  _footerComponents = () => {
    return {
      week: [this._leftFooterComponents(), this._rightFooterComponents()],
    }
  }

  _renderClearButton() {
    if (this.state.proposals.length === 0) {
      return false
    }
    return (
      <button
        key="clear"
        style={{order: -99, marginLeft: 20}}
        onClick={this._onClearProposals}
        className="btn clear-proposed-times"
      >
        Clear Times
      </button>
    )
  }

  _onClearProposals = () => {
    SchedulerActions.clearProposals()
  }

  _leftFooterComponents() {
    const optComponents = ProposedTimeCalendarStore.DURATIONS.map((opt, i) =>
      <option value={opt.join("|")} key={i}>{opt[2]}</option>
    )

    const durationPicker = (
      <div key="dp" className="duration-picker" style={{order: -100}}>
        <label
          htmlFor="duration-picker-select"
          style={{paddingRight: 10}}
        >
          Event Duration:
        </label>
        <select
          id="duration-picker-select"
          className="duration-picker-select"
          value={this.state.duration.join("|")}
          onChange={this._onChangeDuration}
        >
          {optComponents}
        </select>
      </div>
    )

    return ([durationPicker, this._renderClearButton()]);
  }

  _rightFooterComponents() {
    return (
      <button
        key="done"
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
    SchedulerActions.changeDuration(event.target.value.split("|"))
  }

  _onDone = () => {
    const proposals = ProposedTimeCalendarStore.proposals();
    // NOTE: This gets dispatched to the main window
    const {draftClientId} = NylasEnv.getWindowProps()
    SchedulerActions.confirmChoices({proposals, draftClientId});
    // Make sure the action gets to the main window then close this one.
    setTimeout(() => { NylasEnv.close() }, 10)
  }

  _onCalendarMouseUp({time, currentView}) {
    if (currentView !== NylasCalendar.WEEK_VIEW) { return }
    if (time) {
      SchedulerActions.addToProposedTimeBlock(time);
    }
    SchedulerActions.endProposedTimeBlock();
    return
  }

  _onCalendarMouseMove({time, mouseIsDown, currentView}) {
    if (!time || !mouseIsDown || currentView !== NylasCalendar.WEEK_VIEW) { return }
    SchedulerActions.addToProposedTimeBlock(time);
    return
  }

  _onCalendarMouseDown({time, currentView}) {
    if (!time || currentView !== NylasCalendar.WEEK_VIEW) { return }
    SchedulerActions.startProposedTimeBlock(time);
    return
  }

  render() {
    return (
      <NylasCalendar
        dataSource={this._dataSource()}
        bannerComponents={this._bannerComponents()}
        footerComponents={this._footerComponents()}
        onCalendarMouseUp={this._onCalendarMouseUp}
        onCalendarMouseDown={this._onCalendarMouseDown}
        onCalendarMouseMove={this._onCalendarMouseMove}
      />
    )
  }
}
