import _ from 'underscore';
import {AccountStore} from 'nylas-exports'
import DeltaProcessor from './delta-processor'
import NylasSyncWorker from './nylas-sync-worker';

export default class NylasSyncWorkerPool {
  constructor() {
    this._workers = [];
    AccountStore.listen(this._onAccountsChanged, this);
    this._onAccountsChanged();
  }

  _onAccountsChanged() {
    if (NylasEnv.inSpecMode()) { return; }

    const accounts = AccountStore.accounts();
    const workers = _.map(accounts, this._workerForAccount);

    // Stop the workers that are not in the new workers list.
    // These accounts are no longer in our database, so we shouldn't
    // be listening.
    const old = _.without(this._workers, ...workers);
    for (const worker of old) { worker.cleanup(); }

    this._workers = workers;
  }

  _workerForAccount = (account) => {
    const worker = _.find(this._workers, c =>
      c.account().id === account.id);
    if (worker) { return worker; }
    const newWorker = new NylasSyncWorker(account);
    const streams = newWorker.deltaStreams();
    for (const name of Object.keys(streams)) {
      const stream = streams[name];
      stream.onDeltas(DeltaProcessor.process);
    }
    this._workers.push(newWorker);
    newWorker.start();
    return newWorker
  }
}
