const Rx = require('rx')
const EventEmitter = require('events');

class TransactionConnector extends EventEmitter {
  notifyDelta(accountId, transaction) {
    this.emit(accountId, transaction);
  }

  getObservableForAccountId(accountId) {
    return Rx.Observable.create((observer) => {
      this.on(accountId, observer.next);
    });
  }
}

module.exports = new TransactionConnector();
