import _ from 'underscore';
import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import classnames from 'classnames';

export default class MiniMonthView extends React.Component {
  static displayName = 'MiniMonthView';

  static propTypes = {
    value: PropTypes.number,
    onChange: PropTypes.func,
  };

  static defaultProps = {
    value: moment().valueOf(),
    onChange: () => {},
  };

  constructor(props) {
    super(props);
    this.today = moment();
    this.state = this._stateFromProps(props);
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._stateFromProps(newProps));
  }

  _stateFromProps(props) {
    const m = props.value ? moment(props.value) : moment();
    return {
      shownYear: m.year(),
      shownMonth: m.month(),
    };
  }

  _shownMonthMoment() {
    return moment([this.state.shownYear, this.state.shownMonth]);
  }

  _changeMonth = by => {
    const newMonth = this.state.shownMonth + by;
    const newMoment = this._shownMonthMoment().month(newMonth);
    this.setState({
      shownYear: newMoment.year(),
      shownMonth: newMoment.month(),
    });
  };

  _renderLegend() {
    const weekdayGen = moment([2016]);
    const legendEls = [];
    for (let i = 0; i < 7; i++) {
      const dayStr = weekdayGen.weekday(i).format('dd'); // Locale aware!
      legendEls.push(
        <span key={i} className="weekday">
          {dayStr}
        </span>
      );
    }
    return <div className="legend">{legendEls}</div>;
  }

  _onClickDay = event => {
    if (!event.target.dataset.timestamp) {
      return;
    }
    const newVal = moment(parseInt(event.target.dataset.timestamp, 10)).valueOf();
    this.props.onChange(newVal);
  };

  _isSameDay(m1, m2) {
    return m1.dayOfYear() === m2.dayOfYear() && m1.year() === m2.year();
  }

  _renderDays() {
    const dayIter = this._shownMonthMoment().date(1);
    const startWeek = dayIter.week();
    const curMonth = this.state.shownMonth;
    const endWeek = moment(dayIter)
      .date(dayIter.daysInMonth())
      .week();
    const weekEls = [];
    const valDay = moment(this.props.value);
    for (let week = startWeek; week <= endWeek; week++) {
      dayIter.week(week); // Locale aware!
      const dayEls = [];
      for (let weekday = 0; weekday < 7; weekday++) {
        dayIter.weekday(weekday); // Locale aware!
        const dayStr = dayIter.format('D');
        const className = classnames({
          day: true,
          today: this._isSameDay(dayIter, this.today),
          'cur-day': this._isSameDay(dayIter, valDay),
          'cur-month': dayIter.month() === curMonth,
        });
        dayEls.push(
          <div className={className} key={`${week}-${weekday}`} data-timestamp={dayIter.valueOf()}>
            {dayStr}
          </div>
        );
      }
      weekEls.push(
        <div className="week" key={week}>
          {dayEls}
        </div>
      );
    }
    return (
      <div className="day-grid" onClick={this._onClickDay}>
        {weekEls}
      </div>
    );
  }

  render() {
    return (
      <div className="mini-month-view">
        <div className="header">
          <div className="btn btn-icon" onClick={_.partial(this._changeMonth, -1)}>
            &lsaquo;
          </div>
          <span className="month-title">{this._shownMonthMoment().format('MMMM YYYY')}</span>
          <div className="btn btn-icon" onClick={_.partial(this._changeMonth, 1)}>
            &rsaquo;
          </div>
        </div>
        {this._renderLegend()}
        {this._renderDays()}
      </div>
    );
  }
}
