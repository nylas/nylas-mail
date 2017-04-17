const Rx = require('rx-lite')
const EventEmitter = require('events');

class TransactionConnector extends EventEmitter {
  notifyDelta(accountId, transaction) {
    this.emit(accountId, transaction);
  }

  getObservableForAccountId(accountId) {
    return Rx.Observable.create((observer) => {
      this.on(accountId, observer.onNext.bind(observer));
    });
  }
}

module.exports = new TransactionConnector();
