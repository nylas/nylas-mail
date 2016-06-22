const Rx = require('rx')
const bluebird = require('bluebird')
const redis = require("redis");
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

class DeltaStreamQueue {
  setup() {
    this.client = redis.createClient(process.env.REDIS_URL || null);
    this.client.on("error", console.error);
  }

  key(accountId) {
    return `delta-${accountId}`
  }

  notify(accountId, data) {
    this.client.publish(this.key(accountId), JSON.stringify(data))
  }

  fromAccountId(accountId) {
    return Rx.Observable.create((observer) => {
      this.client.on("message", (channel, message) => {
        if (channel !== this.key(accountId)) { return }
        observer.onNext(message)
      });
      this.client.subscribe(this.key(accountId));
      return () => { this.client.unsubscribe() }
    })
  }
}

module.exports = new DeltaStreamQueue()
