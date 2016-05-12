import _ from 'underscore'
import {
  Thread,
  Actions,
  MailboxPerspective,
  SoundRegistry,
  FocusedPerspectiveStore,
  NativeNotifications,
  DatabaseStore,
} from 'nylas-exports';

export class Notifier {
  constructor() {
    this.unlisteners = [];
    this.unlisteners.push(Actions.didPassivelyReceiveNewModels.listen(this._onNewMailReceived, this));
    this.activationTime = Date.now();
    this.stack = [];
    this.stackProcessTimer = null;
  }

  unlisten() {
    for (const unlisten of this.unlisteners) {
      unlisten();
    }
  }

  _notifyAll() {
    NativeNotifications.displayNotification({
      title: `${this.stack.length} Unread Messages`,
      tag: 'unread-update',
    });
    this.stack = [];
  }

  _notifyOne({message, thread}) {
    const from = (message.from[0]) ? message.from[0].displayName() : "Unknown";
    const title = from;
    let subtitle = null;
    let body = null;
    if (message.subject && message.subject.length > 0) {
      subtitle = message.subject;
      body = message.snippet;
    } else {
      subtitle = message.snippet
      body = null
    }

    NativeNotifications.displayNotification({
      title: title,
      subtitle: subtitle,
      body: body,
      canReply: true,
      tag: 'unread-update',
      onActivate: ({response, activationType}) => {
        if ((activationType === 'replied') && response && _.isString(response)) {
          Actions.sendQuickReply({thread, message}, response);
        } else {
          NylasEnv.displayWindow()
        }

        Actions.setFocus({
          collection: 'thread',
          item: thread,
          desiredCategoryName: 'inbox',
        });
      },
    });
  }

  _notifyMessages() {
    if (this.stack.length >= 5) {
      this._notifyAll()
    } else if (this.stack.length > 0) {
      this._notifyOne(this.stack.pop());
    }

    this.stackProcessTimer = null;
    if (this.stack.length > 0) {
      this.stackProcessTimer = setTimeout(() => this._notifyMessages(), 2000);
    }
  }

  // https://phab.nylas.com/D2188
  _onNewMessagesMissingThreads(messages) {
    setTimeout(() => {
      const threads = {}
      for (const {threadId} of messages) {
        threads[threadId] = threads[threadId] || DatabaseStore.find(Thread, threadId);
      }
      Promise.props(threads).then((resolvedThreads) => {
        const resolved = messages.filter((msg) => resolvedThreads[msg.threadId]);
        if (resolved.length > 0) {
          this._onNewMailReceived({message: resolved, thread: _.values(resolvedThreads)});
        }
      });
    }, 10000);
  }

  _onNewMailReceived(incoming) {
    return new Promise((resolve) => {
      if (NylasEnv.config.get('core.notifications.enabled') === false) {
        resolve();
        return;
      }

      const incomingMessages = incoming.message || [];
      const incomingThreads = incoming.thread || [];

      // Filter for new messages that are not sent by the current user
      const newUnread = incomingMessages.filter((msg) => {
        const isUnread = msg.unread === true;
        const isNew = msg.date && msg.date.valueOf() >= this.activationTime;
        const isFromMe = msg.isFromMe();
        return isUnread && isNew && !isFromMe;
      });

      if (newUnread.length === 0) {
        resolve();
        return;
      }

      // For each message, find it's corresponding thread. First, look to see
      // if it's already in the `incoming` payload (sent via delta sync
      // at the same time as the message.) If it's not, try loading it from
      // the local cache.

      // Note we may receive multiple unread msgs for the same thread.
      // Using a map and ?= to avoid repeating work.
      const threads = {}
      for (const {threadId} of newUnread) {
        threads[threadId] = threads[threadId] || _.findWhere(incomingThreads, {id: threadId})
        threads[threadId] = threads[threadId] || DatabaseStore.find(Thread, threadId);
      }

      Promise.props(threads).then((resolvedThreads) => {
        // Filter new unread messages to just the ones in the inbox
        const newUnreadInInbox = newUnread.filter((msg) =>
          resolvedThreads[msg.threadId] && resolvedThreads[msg.threadId].categoryNamed('inbox')
        )

        // Filter messages that we can't decide whether to display or not
        // since no associated Thread object has arrived yet.
        const newUnreadMissingThreads = newUnread.filter((msg) => !resolvedThreads[msg.threadId])

        if (newUnreadMissingThreads.length > 0) {
          this._onNewMessagesMissingThreads(newUnreadMissingThreads);
        }

        if (newUnreadInInbox.length === 0) {
          resolve();
          return;
        }

        for (const msg of newUnreadInInbox) {
          this.stack.push({message: msg, thread: resolvedThreads[msg.threadId]});
        }
        if (!this.stackProcessTimer) {
          if (NylasEnv.config.get("core.notifications.sounds")) {
            SoundRegistry.playSound('new-mail');
          }
          this._notifyMessages();
        }

        resolve();
      });
    });
  }
}

export const config = {
  enabled: {
    'type': 'boolean',
    'default': true,
  },
};

export function activate() {
  this.notifier = new Notifier();
}

export function deactivate() {
  this.notifier.unlisten();
}
