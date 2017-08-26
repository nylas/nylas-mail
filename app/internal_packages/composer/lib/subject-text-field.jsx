import React, {Component} from 'react'
import PropTypes from 'prop-types'

export default class SubjectTextField extends Component {
  static displayName = 'SubjectTextField'

  static containerRequired = false

  static propTypes = {
    value: PropTypes.string,
    onSubjectChange: PropTypes.func,
  }

  onInputChange = ({target: {value}}) => {
    this.props.onSubjectChange(value)
  }

  focus() {
    this._el.focus()
  }

  render() {
    const {value} = this.props

    return (
      <div className="composer-subject subject-field">
        <input
          ref={el => { this._el = el; }}
          type="text"
          name="subject"
          placeholder="Subject"
          value={value}
          onChange={this.onInputChange}
        />
      </div>
    );
  }
}
