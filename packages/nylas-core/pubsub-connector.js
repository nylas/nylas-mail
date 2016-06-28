const Rx = require('rx')
const redis = require("redis");

const SyncPolicy = require('./sync-policy');

Promise.promisifyAll(redis.RedisClient.prototype);
Promise.promisifyAll(redis.Multi.prototype);

class PubsubConnector {
  constructor() {
    this._broadcastClient = null;
    this._listenClient = null;
    this._listenClientSubs = {};
  }

  buildClient() {
    const client = redis.createClient(process.env.REDIS_URL || null);
    client.on("error", console.error);
    return client;
  }

  broadcastClient() {
    if (!this._broadcastClient) {
      this._broadcastClient = this.buildClient();
    }
    return this._broadcastClient;
  }

  // Shared channel
  _observableForChannelOnSharedListener(channel) {
    if (!this._listenClient) {
      this._listenClient = this.buildClient();
      this._listenClientSubs = {};
    }

    return Rx.Observable.create((observer) => {
      this._listenClient.on("message", (msgChannel, message) => {
        if (msgChannel !== channel) { return }
        observer.onNext(message)
      });

      if (!this._listenClientSubs[channel]) {
        this._listenClientSubs[channel] = 1;
        this._listenClient.subscribe(channel);
      } else {
        this._listenClientSubs[channel] += 1;
      }
      return () => {
        this._listenClientSubs[channel] -= 1;
        if (this._listenClientSubs[channel] === 0) {
          this._listenClient.unsubscribe(channel);
        }
      }
    });
  }

  notify({accountId, type, data}) {
    this.broadcastClient().publish(`channel-${accountId}`, {type, data});
  }

  observe(accountId) {
    return this._observableForChannelOnSharedListener(`channel-${accountId}`);
  }

  notifyDelta(accountId, data) {
    this.broadcastClient().publish(`channel-${accountId}-deltas`, JSON.stringify(data))
  }

  observeDeltas(accountId) {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient();
      sub.on("message", (channel, message) => observer.onNext(message));
      sub.subscribe(`channel-${accountId}-deltas`);
      return () => {
        sub.unsubscribe();
        sub.quit();
      }
    })
  }
}

module.exports = new PubsubConnector()
