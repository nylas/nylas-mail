import React, {Component, PropTypes} from 'react'
import {findDOMNode} from 'react-dom'


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
    findDOMNode(this.refs.input).focus()
  }

  render() {
    const {value} = this.props

    return (
      <div className="composer-subject subject-field">
        <input
          ref="input"
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
