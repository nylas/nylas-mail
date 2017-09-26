import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import moment from 'moment';
import classnames from 'classnames';

require('moment-round'); // overrides moment

const INTERVAL = [30, 'minutes'];

export default class TimePicker extends React.Component {
  static displayName = 'TimePicker';

  static propTypes = {
    value: PropTypes.number,
    onChange: PropTypes.func,
    relativeTo: PropTypes.number, // TODO For `renderTimeOptions`
  };

  static contextTypes = {
    parentTabGroup: PropTypes.object,
  };

  static defaultProps = {
    value: moment().valueOf(),
    onChange: () => {},
  };

  constructor(props) {
    super(props);
    this.state = {
      focused: false,
      rawText: this._valToTimeString(props.value),
    };
  }

  componentDidMount() {
    this._fixTimeOptionScroll();
  }

  componentWillReceiveProps(newProps) {
    this.setState({ rawText: this._valToTimeString(newProps.value) });
  }

  componentDidUpdate() {
    if (this._gotoScrollStartOnUpdate) {
      this._fixTimeOptionScroll();
    }
  }

  _valToTimeString(value) {
    return moment(value).format('LT');
  }

  _onKeyDown = event => {
    if (event.key === 'ArrowUp') {
      event.preventDefault();
      this._onArrow(event.key);
    } else if (event.key === 'ArrowDown') {
      event.preventDefault();
      this._onArrow(event.key);
    } else if (event.key === 'Enter') {
      this.context.parentTabGroup.shiftFocus(1);
    }
  };

  _onArrow(key) {
    let newT = moment(this.props.value);
    newT = newT.round(...INTERVAL);
    if (key === 'ArrowUp') {
      newT = newT.subtract(...INTERVAL);
    } else if (key === 'ArrowDown') {
      newT = newT.add(...INTERVAL);
    }
    if (moment(this.props.value).day() !== newT.day()) {
      return;
    }
    this._gotoScrollStartOnUpdate = true;
    this.props.onChange(newT);
  }

  _onFocus = () => {
    this.setState({ focused: true });
    this._gotoScrollStartOnUpdate = true;
    const el = ReactDOM.findDOMNode(this.refs.input);
    el.setSelectionRange(0, el.value.length);
  };

  _onBlur = event => {
    this.setState({ focused: false });
    if (event.relatedTarget && Array.from(event.relatedTarget.classList).includes('time-options')) {
      return;
    }
    this._saveIfValid(this.state.rawText);
  };

  _onRawTextChange = event => {
    this.setState({ rawText: event.target.value });
  };

  _saveIfValid(rawText = '') {
    // Locale-aware am/pm parsing!!
    const parsedMoment = moment(rawText, 'h:ma');
    if (parsedMoment.isValid()) {
      if (this._shouldAddTwelve(rawText) && parsedMoment.hour() < 12) {
        parsedMoment.add(12, 'hours');
      }
      this.props.onChange(parsedMoment.valueOf());
    }
  }

  /*
   * If you're going to punch only "2" into the time field, you probably
   * mean 2pm instead of 2am. The regex explicitly checks for only digits
   * (no meridiem indicators) and very basic use cases.
   */
  _shouldAddTwelve(rawText) {
    const simpleDigitMatch = rawText.match(/^(\d{1,2})(:\d{1,2})?$/);
    if (simpleDigitMatch && simpleDigitMatch.length > 0) {
      const hr = parseInt(simpleDigitMatch[1], 10);
      if (hr <= 7) {
        return true;
      }
    }
    return false;
  }

  _fixTimeOptionScroll() {
    this._gotoScrollStartOnUpdate = false;
    const el = ReactDOM.findDOMNode(this);
    const scrollTo = el.querySelector('.scroll-start');
    const scrollWrap = el.querySelector('.time-options');
    if (scrollTo && scrollWrap) {
      scrollWrap.scrollTop = scrollTo.offsetTop;
    }
  }

  _onSelectOption(val) {
    this.props.onChange(val);
  }

  _renderTimeOptions() {
    if (!this.state.focused) {
      return false;
    }

    const enteredMoment = moment(this.props.value);

    const roundedMoment = moment(enteredMoment);
    roundedMoment.ceil(...INTERVAL);

    const firstVisibleMoment = moment(roundedMoment);
    firstVisibleMoment.add(...INTERVAL);

    let startVal = moment(this.props.value)
      .startOf('day')
      .valueOf();
    startVal = Math.max(startVal, this.props.relativeTo || 0);

    const startMoment = moment(startVal);
    if (this.props.relativeTo) {
      startMoment.ceil(...INTERVAL).add(...INTERVAL);
    }
    const endMoment = moment(startVal).endOf('day');
    const opts = [];

    const relStart = moment(this.props.relativeTo);
    const timeIter = moment(startMoment);
    while (timeIter.isSameOrBefore(endMoment)) {
      const val = timeIter.valueOf();
      const className = classnames({
        option: true,
        selected: timeIter.isSame(enteredMoment),
        'scroll-start': timeIter.isSame(firstVisibleMoment),
      });

      let relTxt = false;
      if (this.props.relativeTo) {
        relTxt = (
          <span className="rel-text">{`(${timeIter.diff(relStart, 'hours', true)}hr)`}</span>
        );
      }

      opts.push(
        <div className={className} key={val} onMouseDown={() => this._onSelectOption(val)}>
          {timeIter.format('LT')}
          {relTxt}
        </div>
      );
      timeIter.add(...INTERVAL);
    }

    const className = classnames({
      'time-options': true,
      'relative-to': this.props.relativeTo,
    });

    return (
      <div className={className} tabIndex={-1}>
        {opts}
      </div>
    );
  }

  render() {
    const className = classnames({
      'time-picker': true,
      'no-select-end': true,
      invalid: !moment(this.state.rawText, 'h:ma').isValid(),
    });
    return (
      <div className="time-picker-wrap">
        <input
          className={className}
          type="text"
          ref="input"
          value={this.state.rawText}
          onChange={this._onRawTextChange}
          onKeyDown={this._onKeyDown}
          onFocus={this._onFocus}
          onBlur={this._onBlur}
        />
        {this._renderTimeOptions()}
      </div>
    );
  }
}
