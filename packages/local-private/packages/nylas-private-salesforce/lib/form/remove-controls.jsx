import React from 'react'
import _str from 'underscore.string'
import {Actions} from 'nylas-exports'
import OpenInSalesforceBtn from '../shared-components/open-in-salesforce-btn'
import DestroySalesforceObjectTask from '../tasks/destroy-salesforce-object-task'

export default class RemoveControls extends React.Component {
  static propTypes = {
    objectId: React.PropTypes.string,
    objectType: React.PropTypes.string,
  }

  constructor(props) {
    super(props);
    this.state = {confirmDelete: false}
  }

  _renderOpenInSalesforce() {
    return [
      <OpenInSalesforceBtn objectId={this.props.objectId} />,
      <span>&nbsp;&nbsp;|&nbsp;&nbsp;</span>,
    ]
  }

  _deleteObject = () => {
    Actions.recordUserEvent("Salesforce Object Delete Submitted", {
      sObjectId: this.props.objectId,
      sObjectType: this.props.objectType,
    });
    const task = new DestroySalesforceObjectTask({
      sObjectId: this.props.objectId,
      sObjectType: this.props.objectType,
    })
    Actions.queueTask(task);
    setTimeout(() => { NylasEnv.close() }, 20)
  }

  render() {
    const confirm = () => this.setState({confirmDelete: true});
    const cancel = () => this.setState({confirmDelete: false});

    let confirmControl
    let confirmControlClass = ""
    if (this.state.confirmDelete) {
      confirmControlClass = "confirm-control"
      confirmControl = (<span>
        Are you sure? This will permanently delete on force.com.
        <br />
        <a onClick={this._deleteObject}>Yes delete</a>
        &nbsp;&nbsp;|&nbsp;&nbsp;
        <a onClick={cancel}>No cancel</a>
      </span>)
    } else {
      const objectName = _str.titleize(_str.humanize(this.props.objectType))
      confirmControl = (
        <span>
          <a onClick={confirm}>Delete {objectName}</a>
        </span>
      )
    }
    return (
      <div className={`salesforce-delete-object ${confirmControlClass}`}>
        {this._renderOpenInSalesforce()}
        {confirmControl}
      </div>
    )
  }
}
