const Rx = require('rx')
const redis = require("redis");
const {PromiseUtils} = require('isomorphic-core');
const log = global.Logger || console;

PromiseUtils.promisifyAll(redis.RedisClient.prototype);
PromiseUtils.promisifyAll(redis.Multi.prototype);


class PubsubConnector {
  constructor() {
    this._broadcastClient = null;
    this._listenClient = null;
    this._listenClientSubs = {};
  }

  buildClient(accountId) {
    const client = redis.createClient(process.env.REDIS_URL || null);
    log.info({account_id: accountId}, "Connecting to Redis")
    client.on("error", log.error);
    return client;
  }

  broadcastClient() {
    if (!this._broadcastClient) {
      this._broadcastClient = this.buildClient("broadcast");
    }
    return this._broadcastClient;
  }

  queueProcessMessage({messageId, accountId}) {
    if (!messageId) {
      throw new Error("queueProcessMessage: The message body processor expects a messageId")
    }
    if (!accountId) {
      throw new Error("queueProcessMessage: The message body processor expects a accountId")
    }
    this.broadcastClient().lpush(`message-processor-queue`, JSON.stringify({messageId, accountId}));
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

  notifyAccount(accountId, {type, data}) {
    this.broadcastClient().publish(`account-${accountId}`, JSON.stringify({type, data}));
  }

  observeAccount(accountId) {
    return this._observableForChannelOnSharedListener(`account-${accountId}`);
  }

  notifyDelta(accountId, transactionJSON) {
    this.broadcastClient().publish(`deltas-${accountId}`, JSON.stringify(transactionJSON))
  }

  observeAllAccounts() {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient();
      sub.on("pmessage", (pattern, channel, message) =>
        observer.onNext(channel.replace('account-', ''), message));
      sub.psubscribe(`account-*`);
      return () => {
        sub.unsubscribe();
        sub.quit();
      }
    })
  }

  observeDeltas(accountId) {
    return Rx.Observable.create((observer) => {
      const sub = this.buildClient(accountId);
      sub.on("message", (channel, transactionJSONString) => {
        observer.onNext(JSON.parse(transactionJSONString))
      })
      sub.subscribe(`deltas-${accountId}`);
      return () => {
        log.info({account_id: accountId}, "Closing Redis")
        sub.unsubscribe();
        sub.quit();
      }
    })
  }
}

module.exports = new PubsubConnector()
