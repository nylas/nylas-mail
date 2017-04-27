const Rx = require('rx-lite')
const redis = require("redis");
const {PromiseUtils} = require('isomorphic-core');

PromiseUtils.promisifyAll(redis.RedisClient.prototype);
PromiseUtils.promisifyAll(redis.Multi.prototype);


class PubsubConnector {
  constructor() {
    this._broadcastClient = null;
    this._listenClient = null;
    this._listenClientSubs = {};
  }

  buildClient(accountId, {onClose} = {}) {
    const client = redis.createClient(process.env.REDIS_URL || null);
    global.Logger.info({account_id: accountId}, "Connecting to Redis")
    client.on("error", (...args) => {
      global.Logger.error(...args);
      if (onClose) onClose();
    });
    client.on("end", () => {
      global.Logger.info({account_id: accountId}, "Redis disconnected");
      if (onClose) onClose();
    })
    return client;
  }

  broadcastClient() {
    if (!this._broadcastClient) {
      this._broadcastClient = this.buildClient("broadcast", {onClose: () => {
        // We null out the memoized broadcast client. In case it closes
        // for any reason, we want to make sure the next time it's
        // requested, we'll create a new one.
        this._broadcastClient = null
      }});
    }
    return this._broadcastClient;
  }

  notifyDelta(accountId, transactionJSON) {
    this.broadcastClient().publish(`deltas-${accountId}`, JSON.stringify(transactionJSON))
  }

  observeDeltas(accountId) {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient(accountId);
      sub.on("message", (channel, transactionJSONString) => {
        observer.onNext(JSON.parse(transactionJSONString))
      })
      sub.subscribe(`deltas-${accountId}`);
      return () => {
        global.Logger.info({account_id: accountId}, "Closing Redis")
        sub.unsubscribe();
        sub.quit();
      }
    })
  }
}

module.exports = new PubsubConnector()
