import _ from 'underscore';
import Message from '../models/message';
import MessageUtils from '../models/message-utils';
import MessageStore from './message-store';
import DatabaseStore from './database-store';

const MessageBodyWidth = 740;

class MessageBodyProcessor {
  constructor() {
    this._subscriptions = [];
    this.resetCache();

    DatabaseStore.listen((change) => {
      if (change.objectClass === Message.name) {
        change.objects.forEach(this.updateCacheForMessage);
      }
    });
  }

  resetCache() {
    // Store an object for recently processed items. Put the item reference into
    // both data structures so we can access it in O(1) and also delete in O(1)
    this._recentlyProcessedA = [];
    this._recentlyProcessedD = {};
    for (const {message, callback} of this._subscriptions) {
      callback(this.process(message));
    }
  }

  updateCacheForMessage = (changedMessage) => {
    // check that the message exists in the cache
    const changedKey = this._key(changedMessage);
    if (!this._recentlyProcessedD[changedKey]) {
      return;
    }

    // remove the message from the cache
    delete this._recentlyProcessedD[changedKey];
    this._recentlyProcessedA = this._recentlyProcessedA.filter(({key}) =>
      key !== changedKey
    );

    // reprocess any subscription using the new message data. Note that
    // changedMessage may not have a loaded body if it wasn't changed. In
    // that case, we use the previous body.
    const subscriptions = this._subscriptions.filter(({message}) =>
      message.id === changedMessage.id
    );

    if (subscriptions.length > 0) {
      const updatedMessage = changedMessage.clone();
      updatedMessage.body = updatedMessage.body || subscriptions[0].message.body;
      const output = this.process(updatedMessage);
      for (const subscription of subscriptions) {
        subscription.callback(output);
        subscription.message = updatedMessage;
      }
    }
  }

  _key(message) {
    // It's safe to key off of the message ID alone because we invalidate the
    // cache whenever the message is persisted to the database.
    return message.id;
  }

  version() {
    return this._version;
  }

  processAndSubscribe(message, callback) {
    _.defer(() => callback(this.process(message)));
    const sub = {message, callback}
    this._subscriptions.push(sub);
    return () => {
      this._subscriptions.splice(this._subscriptions.indexOf(sub), 1);
    }
  }

  process(message) {
    let body = message.body;
    if (!_.isString(message.body)) {
      return "";
    }

    const key = this._key(message);
    if (this._recentlyProcessedD[key]) {
      return this._recentlyProcessedD[key].body;
    }

    // Give each extension the message object to process the body, but don't
    // allow them to modify anything but the body for the time being.
    for (const extension of MessageStore.extensions()) {
      if (!extension.formatMessageBody) {
        continue;
      }
      const previousBody = body;
      try {
        const virtual = message.clone();
        virtual.body = body;
        extension.formatMessageBody({message: virtual});
        body = virtual.body;
      } catch (err) {
        NylasEnv.reportError(err);
        body = previousBody;
      }
    }

    // Find inline images and give them a calculated CSS height based on
    // html width and height, when available. This means nothing changes size
    // as the image is loaded, and we can estimate final height correctly.
    // Note that MessageBodyWidth must be updated if the UI is changed!
    let result = MessageUtils.cidRegex.exec(body);

    while (result !== null) {
      const imgstart = body.lastIndexOf('<', result.index);
      const imgend = body.indexOf('/>', result.index);

      if ((imgstart !== -1) && (imgend > imgstart)) {
        const imgtag = body.substr(imgstart, imgend - imgstart);
        const widthMatch = imgtag.match(/width[ ]?=[ ]?['"]?(\d*)['"]?/);
        const width = widthMatch ? widthMatch[1] : null;
        const heightMatch = imgtag.match(/height[ ]?=[ ]?['"]?(\d*)['"]?/);
        const height = heightMatch ? heightMatch[1] : null;
        if (width && height) {
          const scale = Math.min(1, MessageBodyWidth / width);
          const style = ` style="height:${height * scale}px;" `
          body = body.substr(0, imgend) + style + body.substr(imgend);
        }
      }

      result = MessageUtils.cidRegex.exec(body);
    }
    this.addToCache(key, body);
    return body;
  }

  addToCache(key, body) {
    if (this._recentlyProcessedA.length > 50) {
      const removed = this._recentlyProcessedA.pop()
      delete this._recentlyProcessedD[removed.key]
    }
    const item = {key, body};
    this._recentlyProcessedA.unshift(item);
    this._recentlyProcessedD[key] = item;
  }
}

module.exports = new MessageBodyProcessor();
