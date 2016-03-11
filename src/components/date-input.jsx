import classnames from 'classnames';
import React, {Component, PropTypes} from 'react';
import {DateUtils} from 'nylas-exports';


class DateInput extends Component {
  static displayName = 'DateInput';

  static propTypes = {
    className: PropTypes.string,
    dateFormat: PropTypes.string.isRequired,
    onSubmitDate: PropTypes.func,
  };

  static defaultProps = {
    onSubmitDate: ()=> {},
  };

  constructor(props) {
    super(props)
    this.unmounted = false
    this.state = {
      inputDate: null,
    }
  }

  componentWillUnmount() {
    this.unmounted = true
  }

  onInputKeyDown = (event)=> {
    const {key, target: {value}} = event;
    if (value.length > 0 && ["Enter", "Return"].includes(key)) {
      // This prevents onInputChange from being fired
      event.stopPropagation();
      const date = DateUtils.futureDateFromString(value);
      this.props.onSubmitDate(date, value);

      // this.props.onSubmitDate may have unmounted this component
      if (!this.unmounted) {
        this.setState({inputDate: null})
      }
    }
  };

  onInputChange = (event)=> {
    this.setState({inputDate: DateUtils.futureDateFromString(event.target.value)});
  };

  render() {
    let dateInterpretation;
    if (this.state.inputDate) {
      dateInterpretation = (
        <span className="date-interpretation">
          {DateUtils.format(this.state.inputDate, this.props.dateFormat)}
        </span>
      );
    }
    const {className} = this.props
    const classes = classnames({
      "nylas-date-input": true,
      [className]: className != null,
    })

    return (
      <div className={classes}>
        <input
          tabIndex="1"
          type="text"
          placeholder="Or, 'next Monday at 2PM'"
          onKeyDown={this.onInputKeyDown}
          onChange={this.onInputChange}/>
        {dateInterpretation}
      </div>
    )
  }
}

export default DateInput
