import _ from 'underscore';
import {AccountStore} from 'nylas-exports'
import NylasSyncWorker from './nylas-sync-worker';

export default class NylasSyncWorkerPool {
  constructor() {
    this._workers = [];
    AccountStore.listen(this._determineWorkerPool, this);
    this._determineWorkerPool();
  }

  _existingWorkerForAccount(account) {
    return _.find(this._workers, c => c.account().id === account.id);
  }

  _determineWorkerPool() {
    if (NylasEnv.inSpecMode()) { return; }
    const origWorkers = this._workers;
    const currentWorkers = []
    Promise.each(AccountStore.accounts(), (account) => {
      const existingWorker = this._existingWorkerForAccount(account)
      if (existingWorker) {
        currentWorkers.push(existingWorker);
        return Promise.resolve()
      }

      const newWorker = new NylasSyncWorker(account);
      return newWorker.loadStateFromDatabase().then(() => {
        newWorker.start()
        currentWorkers.push(newWorker);
      })
    }).then(() => {
      const oldWorkers = _.difference(origWorkers, currentWorkers);
      for (const worker of oldWorkers) { worker.cleanup() }
      this._workers = currentWorkers;
    })
  }
}
