import React from 'react'
import _str from 'underscore.string'
import {Switch} from 'nylas-component-kit'
import {Actions} from 'nylas-exports'
import * as mdHelpers from '../metadata-helpers'
import SyncThreadActivityToSalesforceTask from '../tasks/sync-thread-activity-to-salesforce-task'

export default function SyncThreadToggle(props) {
  const checked = mdHelpers.getSObjectsToSyncActivityTo(props.thread)[props.sObjectId]

  const onChange = () => {
    const newSObjectsToSync = []
    const sObjectsToStopSyncing = []
    const obj = {id: props.sObjectId, type: props.sObjectType}

    let mixpanelEvent;
    if (checked) {
      mixpanelEvent = "Salesforce Thread Unsynced";
      sObjectsToStopSyncing.push(obj)
    } else {
      mixpanelEvent = "Salesforce Thread Synced";
      newSObjectsToSync.push(obj)
    }
    const task = new SyncThreadActivityToSalesforceTask({
      threadId: props.thread.id,
      threadClientId: props.thread.clientId,
      newSObjectsToSync: newSObjectsToSync,
      sObjectsToStopSyncing: sObjectsToStopSyncing,
    })

    Actions.queueTask(task);

    Actions.recordUserEvent(mixpanelEvent, {
      threadId: props.thread.id,
      sObjectId: obj.id,
      sObjectType: obj.type,
    });
  }

  const objName = _str.titleize(_str.humanize(props.sObjectType))
  const msgOn = `Upload all messages to this ${objName}`
  const msgOff = `Remove all messages from this ${objName}`
  const title = checked ? msgOff : msgOn

  return (
    <span className="sync-thread-toggle" title={title}>
      Sync:&nbsp;&nbsp;&nbsp;&nbsp;
      <Switch
        onChange={onChange}
        checked={checked}
      />
    </span>
  )
}
SyncThreadToggle.displayName = "SyncThreadToggle"
SyncThreadToggle.propTypes = {
  thread: React.PropTypes.object,
  sObjectId: React.PropTypes.string,
  sObjectType: React.PropTypes.string,
}
