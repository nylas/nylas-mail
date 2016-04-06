import React from 'react'
import moment from 'moment'
import classnames from 'classnames'
import {DateUtils} from 'nylas-exports'
import {MiniMonthView} from 'nylas-component-kit'

export default class DatePicker extends React.Component {
  static displayName = "DatePicker";

  static propTypes = {
    value: React.PropTypes.number,
    onChange: React.PropTypes.func,
  }

  static contextTypes = {
    parentTabGroup: React.PropTypes.object,
  }

  static defaultProps = {
    value: moment().valueOf(),
    onChange: () => {},
  }

  constructor(props) {
    super(props);
    this.state = {focused: false}
  }

  _moveDay(numDays) {
    const val = moment(this.props.value)
    const day = val.dayOfYear();
    this.props.onChange(val.dayOfYear(day + numDays).valueOf())
  }

  _onKeyDown = (event) => {
    if (event.key === "ArrowLeft") {
      this._moveDay(-1)
    } else if (event.key === "ArrowRight") {
      this._moveDay(1)
    } else if (event.key === "ArrowUp") {
      this._moveDay(-7)
    } else if (event.key === "ArrowDown") {
      this._moveDay(7)
    } else if (event.key === "Enter") {
      this.context.parentTabGroup.shiftFocus(1);
    }
  }

  _onFocus = () => {
    this.setState({focused: true})
  }

  _onBlur = () => {
    this.setState({focused: false})
  }

  _onSelectDay = (newTimestamp) => {
    this.props.onChange(newTimestamp)
    this.context.parentTabGroup.shiftFocus(1);
  }

  _renderMiniMonthView() {
    if (this.state.focused) {
      return (
        <div className="mini-month-view-wrap">
          <MiniMonthView
            onChange={this._onSelectDay}
            value={this.props.value}
          />
        </div>
      )
    }
    return false
  }

  render() {
    const className = classnames({
      'day-text': true,
      focused: this.state.focused,
    })

    const dayTxt = moment(this.props.value).format(DateUtils.DATE_FORMAT_llll_NO_TIME)

    return (
      <div tabIndex={0} className="date-picker"
        onKeyDown={this._onKeyDown} onFocus={this._onFocus}
        onBlur={this._onBlur}
      >
        <div className={className}>{dayTxt}</div>
        {this._renderMiniMonthView()}
      </div>
    )
  }
}
