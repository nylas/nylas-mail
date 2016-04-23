import NylasStore from 'nylas-store';
import Rx from 'rx-lite';

import {Message,
  DatabaseStore,
  NativeNotifications} from 'nylas-exports';

const OPEN_TRACKING_ID = "1hnytbkg4wd1ahodatwxdqlb5";
const LINK_TRACKING_ID = "a1ec1s3ieddpik6lpob74hmcq";


class ActivityListStore extends NylasStore {
  constructor() {
    super();
  }

  activate() {
    this._getActivity();
  }

  actions() {
    return this._actions;
  }

  _getActivity() {
    const query = DatabaseStore.findAll(Message).where(Message.attributes.pluginMetadata.contains(OPEN_TRACKING_ID, LINK_TRACKING_ID));
    this._subscription = Rx.Observable.fromQuery(query).subscribe((messages) => {
      this._actions = messages ? this._getActions(messages) : [];
      this.trigger();
    });
  }

  _getActions(messages) {
    let actions = [];
    this._notifications = [];
    for (const message of messages) {
      if (message.metadataForPluginId(OPEN_TRACKING_ID) ||
        message.metadataForPluginId(LINK_TRACKING_ID)) {
        actions = actions.concat(this._openActionsForMessage(message));
        actions = actions.concat(this._linkActionsForMessage(message));
      }
    }
    for (const notification of this._notifications) {
      NativeNotifications.displayNotification(notification);
    }
    const d = new Date();
    this._lastChecked = d.getTime() / 1000;
    return actions.sort((a, b) => {return b.timestamp - a.timestamp;});
  }

  _getRecipients(message) {
    const recipients = message.to.concat(message.cc, message.bcc);
    return recipients;
  }

  _openActionsForMessage(message) {
    const openMetadata = message.metadataForPluginId(OPEN_TRACKING_ID);
    const recipients = this._getRecipients(message);
    const actions = [];
    if (openMetadata) {
      if (openMetadata.open_count > 0) {
        for (const open of openMetadata.open_data) {
          if (open.timestamp > this._lastChecked) {
            this._notifications.push({
              title: "New open",
              subtitle: `${recipients.length === 1 ? recipients[0].name : "Someone"} just opened your email.`,
              body: message.subject,
              canReply: false,
              tag: "message-open",
              onActivate: () => {
                NylasEnv.displayWindow();
              },
            });
          }
          actions.push({
            messageId: message.id,
            title: message.subject,
            recipients: recipients,
            pluginId: OPEN_TRACKING_ID,
            timestamp: open.timestamp,
          });
        }
      }
    }
    return actions;
  }

  _linkActionsForMessage(message) {
    const linkMetadata = message.metadataForPluginId(LINK_TRACKING_ID)
    const recipients = this._getRecipients(message);
    const actions = [];
    if (linkMetadata && linkMetadata.links) {
      for (const link of linkMetadata.links) {
        for (const click of link.click_data) {
          if (click.timestamp > this._lastChecked) {
            this._notifications.push({
              title: "New click",
              subtitle: `${recipients.length === 1 ? recipients[0].name : "Someone"} just clicked your link.`,
              body: link.url,
              canReply: false,
              tag: "link-open",
              onActivate: () => {
                NylasEnv.displayWindow();
              },
            });
          }
          actions.push({
            messageId: message.id,
            title: link.url,
            recipients: recipients,
            pluginId: LINK_TRACKING_ID,
            timestamp: click.timestamp,
          });
        }
      }
    }
    return actions;
  }
}

export default new ActivityListStore();
