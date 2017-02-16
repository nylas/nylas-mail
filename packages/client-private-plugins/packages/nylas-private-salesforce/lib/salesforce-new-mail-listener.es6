import _ from 'underscore';

import NylasStore from 'nylas-store';
import { Thread, Actions, DatabaseStore } from 'nylas-exports';

import SalesforceEnv from './salesforce-env';

import SyncThreadActivityToSalesforceTask from './tasks/sync-thread-activity-to-salesforce-task';

import * as mdHelpers from './metadata-helpers'

class SalesforceNewMailListener extends NylasStore {

  activate() {
    this.listenTo(Actions.onNewMailDeltas, this._newMailReceived);
    this.listenTo(Actions.draftDeliverySucceeded, this._onSendDraftSuccess);
  }

  deactivate() {
    return this.stopListeningToAll();
  }

  _ensureThreadSynced = (thread) => {
    if (!thread) return;
    const ids = Object.keys(mdHelpers.getSObjectsToSyncActivityTo(thread));
    if (ids.length === 0) return;
    const task = new SyncThreadActivityToSalesforceTask({
      threadId: thread.id, threadClientId: thread.clientId,
    });
    Actions.queueTask(task);
  }

  /**
   * For replies, the thread will exist. For new messages, the thread will
   * not exist, but will come in shortly via
   * `didPassivelyReceivedNewModels`.
   */
  _onSendDraftSuccess = ({message}) => {
    return DatabaseStore.find(Thread, message.threadId)
    .then(this._ensureThreadSynced)
  }

  _newMailReceived = (incoming) => {
    if (!SalesforceEnv.isLoggedIn()) return;
    if (!incoming.message || incoming.message.length <= 0) { return; }
    const tids = _.pluck(incoming.message, "threadId");
    const incomingThreads = incoming.thread || [];
    Promise.map(tids, (tid) => {
      const thread = _.findWhere(incomingThreads, {id: tid});
      if (thread) return thread;
      return DatabaseStore.find(Thread, tid)
    }).each(this._ensureThreadSynced);
  }
}

export default new SalesforceNewMailListener();
