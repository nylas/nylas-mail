import {React} from 'nylas-exports'
import {PLUGIN_ID} from '../salesforce-constants'
import * as mdHelpers from '../metadata-helpers'
import SalesforceActions from '../salesforce-actions'
import SalesforceIcon from '../shared-components/salesforce-icon'

export default class SalesforceSyncMessageStatus extends React.Component {
  static displayName = "SalesforceSyncMessageStatus";
  static containerRequired = false;

  static propTypes = {
    message: React.PropTypes.object.isRequired,
  };

  static containerStyles = {
    paddingTop: 4,
  };

  _getRelatedIds() {
    const taskIds = []
    const emailMessageIds = []

    const clonedAs = mdHelpers.getClonedAs(this.props.message);
    for (const relatedToId of Object.keys(clonedAs)) {
      for (const clonedSObjectId of Object.keys(clonedAs[relatedToId])) {
        const clonedObj = clonedAs[relatedToId][clonedSObjectId] || {}
        if (clonedObj.type === "Task") taskIds.push(clonedSObjectId)
        if (clonedObj.type === "EmailMessage") emailMessageIds.push(clonedSObjectId)
      }
    }

    return {taskIds, emailMessageIds}
  }

  _hasRelatedSObject() {
    const {taskIds, emailMessageIds} = this._getRelatedIds();
    return taskIds.length > 0 || emailMessageIds.length > 0
  }

  _editActivityBtn(type, id) {
    const onClick = () => {
      SalesforceActions.openObjectForm({
        objectId: id,
        objectType: type,
      })
    }
    return <SalesforceIcon className="inline" objectType={type} onClick={onClick} />
  }

  _editEmailMessageFn(id) {
    SalesforceActions.openObjectForm({
      objectId: id,
      objectType: "EmailMessage",
    })
  }

  _isPendingSync() {
    return (this.props.message.metadataForPluginId(PLUGIN_ID) || {}).pendingSync
  }

  _renderPendingSync() {
    return <div className="salesforce-sync-message-status">Syncing to Salesforce…</div>
  }

  render() {
    if (this._isPendingSync()) return this._renderPendingSync();
    if (!this._hasRelatedSObject()) return false;
    const {taskIds, emailMessageIds} = this._getRelatedIds();
    const id = emailMessageIds[0] || taskIds[0];

    const tasks = taskIds.map((taskId) => {
      return this._editActivityBtn("Task", taskId)
    })
    const emailMessages = emailMessageIds.map((emailMessageId) => {
      return this._editActivityBtn("EmailMessage", emailMessageId)
    })

    if (!id) return false;
    return (
      <div className="salesforce-sync-message-status">
        Synced to Salesforce:
        {tasks}
        {emailMessages}
      </div>
    )
  }
}
