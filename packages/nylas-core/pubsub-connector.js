const Rx = require('rx')
const bluebird = require('bluebird')
const redis = require("redis");
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

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

  channelForAccount(accountId) {
    return `a-${accountId}`;
  }

  channelForAccountDeltas(accountId) {
    return `a-${accountId}-deltas`;
  }

  // Shared channel

  notifyAccountChange(accountId) {
    const channel = this.channelForAccount(accountId);
    this.broadcastClient().publish(channel, 'modified');
  }

  observableForAccountChanges(accountId) {
    if (!this._listenClient) {
      this._listenClient = this.buildClient();
      this._listenClientSubs = {};
    }

    const channel = this.channelForAccount(accountId);
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
    })
  }


  // Account (delta streaming) channels

  notifyAccountDeltas(accountId, data) {
    const channel = this.channelForAccountDeltas(accountId);
    this.broadcastClient().publish(channel, JSON.stringify(data))
  }

  observableForAccountDeltas(accountId) {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient();
      sub.on("message", (channel, message) => observer.onNext(message));
      sub.subscribe(this.channelForAccountDeltas(accountId));
      return () => {
        sub.unsubscribe();
        sub.quit();
      }
    })
  }
}

module.exports = new PubsubConnector()
