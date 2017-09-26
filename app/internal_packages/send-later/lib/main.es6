import {
  ComponentRegistry,
  DatabaseStore,
  SyncbackMetadataTask,
  Message,
  SendActionsStore,
  Actions,
} from 'mailspring-exports';
import { HasTutorialTip } from 'mailspring-component-kit';

import SendLaterButton from './send-later-button';
import SendLaterStatus from './send-later-status';
import { PLUGIN_ID } from './send-later-constants';

const SendLaterButtonWithTip = HasTutorialTip(SendLaterButton, {
  title: 'Send on your own schedule',
  instructions:
    'Schedule this message to send at the ideal time. N1 makes it easy to control the fabric of spacetime!',
});

let unlisten = null;

export function activate() {
  ComponentRegistry.register(SendLaterButtonWithTip, { role: 'Composer:ActionButton' });
  ComponentRegistry.register(SendLaterStatus, { role: 'DraftList:DraftStatus' });

  unlisten = DatabaseStore.listen(change => {
    if (change.type !== 'metadata-expiration' || change.objectClass !== Message.name) {
      return;
    }
    for (const message of change.objects) {
      const metadata = message.metadataForPluginId(PLUGIN_ID);
      if (!metadata || !metadata.expiration || metadata.expiration > new Date()) {
        continue;
      }

      // clear the metadata
      Actions.queueTask(
        new SyncbackMetadataTask({
          model: message,
          pluginId: PLUGIN_ID,
          value: {
            expiration: null,
          },
        })
      );

      if (!message.draft) {
        continue;
      }

      // send the draft
      Actions.sendDraft(message.headerMessageId, SendActionsStore.DefaultSendActionKey);
    }
  });
}

export function deactivate() {
  ComponentRegistry.unregister(SendLaterButtonWithTip);
  ComponentRegistry.unregister(SendLaterStatus);
  unlisten();
}

export function serialize() {}
