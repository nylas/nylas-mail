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

  subscribe(accountId, callback) {
    this.client.on("message", (channel, message) => {
      if (channel !== this.key(accountId)) { return }
      callback(message)
    })
    this.client.subscribe(this.key(accountId))
  }
}

module.exports = new DeltaStreamQueue()
