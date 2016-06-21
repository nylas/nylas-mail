const bluebird = require('bluebird')
const redis = require("redis");
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

class DeltaStreamQueue {
  setup() {
    this.client = redis.createClient();
    this.client.on("error", console.error);
    this.client.on("ready", () => console.log("Redis ready"));
  }

  key(accountId) {
    return `delta-${accountId}`
  }

  hasSubscribers(accountId) {
    return this.client.existsAsync(this.key(accountId))
  }

  notify(accountId, data) {
    return this.hasSubscribers(accountId).then((hasSubscribers) => {
      if (!hasSubscribers) return Promise.resolve()
      return this.client.rpushAsync(this.key(accountId), JSON.stringify(data))
    })
  }
}

module.exports = new DeltaStreamQueue()
