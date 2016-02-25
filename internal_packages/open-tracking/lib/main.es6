import request from 'request';
import {ComponentRegistry, ExtensionRegistry, Actions} from 'nylas-exports';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingMessageStatus from './open-tracking-message-status';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants'

const post = Promise.promisify(request.post, {multiArgs: true});


function afterDraftSend({message}) {
  // only run this handler in the main window
  if (!NylasEnv.isMainWindow()) return;

  // grab message metadata, if any
  const metadata = message.metadataForPluginId(PLUGIN_ID);

  // get the uid from the metadata, if present
  if (metadata) {
    const uid = metadata.uid;

    // post the uid and message id pair to the plugin server
    const data = {uid: uid, message_id: message.id, thread_id: 1};
    const serverUrl = `${PLUGIN_URL}/plugins/register-message`;

    post({
      url: serverUrl,
      body: JSON.stringify(data),
    }).then(([response, responseBody]) => {
      if (response.statusCode !== 200) {
        throw new Error(responseBody);
      }
    }).catch(error => {
      NylasEnv.showErrorDialog(`There was a problem saving your open tracking settings. This message will not have open tracking. ${error.message}`);
      Promise.reject(error);
    });
  }
}

export function activate() {
  ComponentRegistry.register(OpenTrackingButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(OpenTrackingIcon, {role: 'ThreadListIcon'});
  ComponentRegistry.register(OpenTrackingMessageStatus, {role: 'MessageHeaderStatus'});
  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButton);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ComponentRegistry.unregister(OpenTrackingMessageStatus);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess()
}
