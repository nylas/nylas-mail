const ThreadUnsubscribeStore = require('./thread-unsubscribe-store');

class ThreadUnsubscribeStoreManager {
  constructor() {
    this.threads = {};
  }

  getStoreForThread(thread) {
    const id = thread.id;
    if (this.threads[id] === undefined) {
      this.threads[id] = new ThreadUnsubscribeStore(thread);
    }
    return this.threads[id];
  }
}

module.exports = new ThreadUnsubscribeStoreManager();
