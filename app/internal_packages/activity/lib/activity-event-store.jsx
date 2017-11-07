import MailspringStore from 'mailspring-store';
import {
  Actions,
  Thread,
  DatabaseStore,
  NativeNotifications,
  FocusedPerspectiveStore,
} from 'mailspring-exports';

import ActivityActions from './activity-actions';
import ActivityDataSource from './activity-data-source';
import { pluginFor } from './plugin-helpers';

class ActivityEventStore extends MailspringStore {
  activate() {
    this.listenTo(ActivityActions.resetSeen, this._onResetSeen);
    this.listenTo(FocusedPerspectiveStore, this._updateActivity);

    const start = () => this._getActivity();
    if (AppEnv.inSpecMode()) {
      start();
    } else {
      setTimeout(start, 2000);
    }
  }

  deactivate() {
    // todo
  }

  actions() {
    return this._actions;
  }

  unreadCount() {
    if (this._unreadCount < 1000) {
      return this._unreadCount;
    } else if (!this._unreadCount) {
      return null;
    }
    return '999+';
  }

  hasBeenViewed(action) {
    if (!AppEnv.savedState.activityListViewed) return false;
    return action.timestamp < AppEnv.savedState.activityListViewed;
  }

  focusThread(threadId) {
    AppEnv.displayWindow();
    Actions.closePopover();
    DatabaseStore.find(Thread, threadId).then(thread => {
      if (!thread) {
        AppEnv.reportError(
          new Error(`ActivityEventStore::focusThread: Can't find thread`, { threadId })
        );
        AppEnv.showErrorDialog(`Can't find the selected thread in your mailbox`);
        return;
      }
      Actions.ensureCategoryIsFocused('sent', thread.accountId);
      Actions.setFocus({ collection: 'thread', item: thread });
    });
  }

  getRecipient(recipientEmail, recipients) {
    if (recipientEmail) {
      for (const recipient of recipients) {
        if (recipientEmail === recipient.email) {
          return recipient;
        }
      }
    } else if (recipients.length === 1) {
      return recipients[0];
    }
    return null;
  }

  _dataSource() {
    return new ActivityDataSource();
  }

  _onResetSeen() {
    AppEnv.savedState.activityListViewed = Date.now() / 1000;
    this._unreadCount = 0;
    this.trigger();
  }

  _getActivity() {
    const dataSource = this._dataSource();
    this._subscription = dataSource
      .buildObservable({
        openTrackingId: AppEnv.packages.pluginIdFor('open-tracking'),
        linkTrackingId: AppEnv.packages.pluginIdFor('link-tracking'),
        messageLimit: 500,
      })
      .subscribe(messages => {
        this._messages = messages;
        this._updateActivity();
      });
  }

  _updateActivity() {
    this._actions = this._messages ? this._getActions(this._messages) : [];
    this.trigger();
  }

  _getActions(messages) {
    let actions = [];
    this._notifications = [];
    this._unreadCount = 0;
    const sidebarAccountIds = FocusedPerspectiveStore.sidebarAccountIds();
    for (const message of messages) {
      if (sidebarAccountIds.length > 1 || message.accountId === sidebarAccountIds[0]) {
        const openTrackingId = AppEnv.packages.pluginIdFor('open-tracking');
        const linkTrackingId = AppEnv.packages.pluginIdFor('link-tracking');
        if (
          message.metadataForPluginId(openTrackingId) ||
          message.metadataForPluginId(linkTrackingId)
        ) {
          actions = actions.concat(this._openActionsForMessage(message));
          actions = actions.concat(this._linkActionsForMessage(message));
        }
      }
    }
    if (!this._lastNotified) this._lastNotified = {};
    for (const notification of this._notifications) {
      const lastNotified = this._lastNotified[notification.threadId];
      const { notificationInterval } = pluginFor(notification.pluginId);
      if (!lastNotified || lastNotified < Date.now() - notificationInterval) {
        NativeNotifications.displayNotification(notification.data);
        this._lastNotified[notification.threadId] = Date.now();
      }
    }
    const d = new Date();
    this._lastChecked = d.getTime() / 1000;

    actions = actions.sort((a, b) => b.timestamp - a.timestamp);
    // For performance reasons, only display the last 100 actions
    if (actions.length > 100) {
      actions.length = 100;
    }
    return actions;
  }

  _openActionsForMessage(message) {
    const openTrackingId = AppEnv.packages.pluginIdFor('open-tracking');
    const openMetadata = message.metadataForPluginId(openTrackingId);
    const recipients = message.to.concat(message.cc, message.bcc);
    const actions = [];
    if (openMetadata) {
      if (openMetadata.open_count > 0) {
        for (const open of openMetadata.open_data) {
          const recipient = this.getRecipient(open.recipient, recipients);
          if (open.timestamp > this._lastChecked) {
            this._notifications.push({
              pluginId: openTrackingId,
              threadId: message.threadId,
              data: {
                title: 'New open',
                subtitle: `${recipient
                  ? recipient.displayName()
                  : 'Someone'} just opened ${message.subject}`,
                canReply: false,
                tag: 'message-open',
                onActivate: () => {
                  this.focusThread(message.threadId);
                },
              },
            });
          }
          if (!this.hasBeenViewed(open)) this._unreadCount += 1;
          actions.push({
            messageId: message.id,
            threadId: message.threadId,
            title: message.subject,
            recipient: recipient,
            pluginId: openTrackingId,
            timestamp: open.timestamp,
          });
        }
      }
    }
    return actions;
  }

  _linkActionsForMessage(message) {
    const linkTrackingId = AppEnv.packages.pluginIdFor('link-tracking');
    const linkMetadata = message.metadataForPluginId(linkTrackingId);
    const recipients = message.to.concat(message.cc, message.bcc);
    const actions = [];
    if (linkMetadata && linkMetadata.links) {
      for (const link of linkMetadata.links) {
        for (const click of link.click_data) {
          const recipient = this.getRecipient(click.recipient, recipients);
          if (click.timestamp > this._lastChecked) {
            this._notifications.push({
              pluginId: linkTrackingId,
              threadId: message.threadId,
              data: {
                title: 'New click',
                subtitle: `${recipient
                  ? recipient.displayName()
                  : 'Someone'} just clicked ${link.url}.`,
                canReply: false,
                tag: 'link-open',
                onActivate: () => {
                  this.focusThread(message.threadId);
                },
              },
            });
          }
          if (!this.hasBeenViewed(click)) this._unreadCount += 1;
          actions.push({
            messageId: message.id,
            threadId: message.threadId,
            title: link.url,
            recipient: recipient,
            pluginId: linkTrackingId,
            timestamp: click.timestamp,
          });
        }
      }
    }
    return actions;
  }
}

export default new ActivityEventStore();
