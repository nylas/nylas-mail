import React from 'react'
import ReactDOM from 'react-dom'
import moment from 'moment'
import classnames from 'classnames'

export default class TimePicker extends React.Component {
  static displayName = "TimePicker";

  static propTypes = {
    value: React.PropTypes.number,
    onChange: React.PropTypes.func,
    relativeTo: React.PropTypes.number, // TODO For `renderTimeOptions`
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
    this.state = {
      focused: false,
      rawText: this._valToTimeString(props.value),
    }
  }

  componentWillReceiveProps(newProps) {
    this.setState({rawText: this._valToTimeString(newProps.value)})
  }

  _valToTimeString(value) {
    return moment(value).format("LT")
  }

  _onKeyDown = (event) => {
    if (event.key === "ArrowUp") {
      // TODO: When `renderTimeOptions` is implemented
    } else if (event.key === "ArrowDown") {
      // TODO: When `renderTimeOptions` is implemented
    } else if (event.key === "Enter") {
      this.context.parentTabGroup.shiftFocus(1);
    }
  }

  _onFocus = () => {
    this.setState({focused: true});
    const el = ReactDOM.findDOMNode(this.refs.input);
    el.setSelectionRange(0, el.value.length)
  }

  _onBlur = () => {
    this.setState({focused: false})
    this._saveIfValid(this.state.rawText)
  }

  _onRawTextChange = (event) => {
    this.setState({rawText: event.target.value});
  }

  _saveIfValid(rawText = "") {
    // Locale-aware am/pm parsing!!
    const parsedMoment = moment(rawText, "h:ma");
    if (parsedMoment.isValid()) {
      if (this._shouldAddTwelve(rawText) && parsedMoment.hour() < 12) {
        parsedMoment.add(12, 'hours');
      }
      this.props.onChange(parsedMoment.valueOf())
    }
  }

  /**
   * If you're going to punch only "2" into the time field, you probably
   * mean 2pm instead of 2am. The regex explicitly checks for only digits
   * (no meridiem indicators) and very basic use cases.
   */
  _shouldAddTwelve(rawText) {
    const simpleDigitMatch = rawText.match(/^(\d{1,2})(:\d{1,2})?$/);
    if (simpleDigitMatch && simpleDigitMatch.length > 0) {
      const hr = parseInt(simpleDigitMatch[1], 10);
      if (hr <= 7) {
        // If you're going to punch in "2" into the time field, you
        // probably mean 2pm, not 2am.
        return true
      }
    }
    return false
  }

  // TODO
  _renderTimeOptions() {
    // TODO: When you select a time a dropdown will additionally show
    // letting you pick from preset times. The `relativeTo` prop will give
    // you relative times
    const opts = []
    if (this.state.focused) {
      return (
        <div className="time-options">{opts}</div>
      )
    }
    return false
  }

  render() {
    const className = classnames({
      "time-picker": true,
      "no-select-end": true,
      invalid: !moment(this.state.rawText, "h:ma").isValid(),
    })
    return (
      <div className="time-picker-wrap">
        <input className={className}
          type="text"
          ref="input"
          value={this.state.rawText}
          onChange={this._onRawTextChange}
          onKeyDown={this._onKeyDown} onFocus={this._onFocus}
          onBlur={this._onBlur}
        />
        {this._renderTimeOptions()}
      </div>
    )
  }
}
