import React, {Component, PropTypes} from 'react'
import {pickHTMLProps} from 'pick-react-known-prop'
import MailMergeToken from './mail-merge-token'


function getInputSize(value) {
  return ((value || '').length || 1) + 1
}

class MailMergeHeaderInput extends Component {

  static propTypes = {
    draftClientId: PropTypes.string,
    colIdx: PropTypes.any,
    tableDataSource: PropTypes.object,
    defaultValue: PropTypes.string,
    onBlur: PropTypes.func,
  }

  constructor(props) {
    super(props)
    this.state = {inputSize: getInputSize(props.defaultValue)}
  }

  componentWillReceiveProps(nextProps) {
    this.setState({inputSize: getInputSize(nextProps.defaultValue)})
  }

  onInputBlur = (event) => {
    const {target: {value}} = event
    this.setState({inputSize: getInputSize(value)})
    // Can't override the original onBlur handler
    this.props.onBlur(event)
  }

  onInputChange = (event) => {
    const {target: {value}} = event
    this.setState({inputSize: getInputSize(value)})
  }

  render() {
    const {inputSize} = this.state
    const {draftClientId, tableDataSource, colIdx, ...props} = this.props
    const colName = tableDataSource.colAt(colIdx)

    return (
      <div className="header-cell">
        <MailMergeToken
          draggable
          colIdx={colIdx}
          colName={colName}
          draftClientId={draftClientId}
        >
          <input
            {...pickHTMLProps(props)}
            size={inputSize}
            onBlur={this.onInputBlur}
            onChange={this.onInputChange}
            defaultValue={props.defaultValue}
          />
        </MailMergeToken>
      </div>
    )
  }
}

export default MailMergeHeaderInput
