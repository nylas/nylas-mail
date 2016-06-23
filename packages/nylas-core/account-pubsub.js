const Rx = require('rx')
const bluebird = require('bluebird')
const redis = require("redis");
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

class AccountPubsub {
  constructor() {
    this._broadcastClient = null;
  }

  buildClient() {
    const client = redis.createClient(process.env.REDIS_URL || null);
    client.on("error", console.error);
    return client;
  }

  keyForAccountId(accountId) {
    return `delta-${accountId}`;
  }

  notify(accountId, data) {
    if (!this._broadcastClient) {
      this._broadcastClient = this.buildClient();
    }
    const key = this.keyForAccountId(accountId);
    this._broadcastClient.publish(key, JSON.stringify(data))
  }

  observableForAccountId(accountId) {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient();
      const key = this.keyForAccountId(accountId);
      sub.on("message", (channel, message) => {
        if (channel !== key) { return }
        observer.onNext(message)
      });
      sub.subscribe(key);
      return () => {
        sub.unsubscribe()
        sub.quit()
      }
    })
  }
}

module.exports = new AccountPubsub()
