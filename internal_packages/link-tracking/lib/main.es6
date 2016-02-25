import request from 'request';
import {ComponentRegistry, ExtensionRegistry, Actions} from 'nylas-exports';
import LinkTrackingButton from './link-tracking-button';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingMessageExtension from './link-tracking-message-extension';
import {PLUGIN_ID, PLUGIN_URL} from './link-tracking-constants';

const post = Promise.promisify(request.post, {multiArgs: true});


function afterDraftSend({message}) {
  // only run this handler in the main window
  if (!NylasEnv.isMainWindow()) return;

  // grab message metadata, if any
  const metadata = message.metadataForPluginId(PLUGIN_ID);
  if (metadata) {
      // get the uid from the metadata, if present
    const uid = metadata.uid;

    // post the uid and message id pair to the plugin server
    const data = {uid: uid, message_id: message.id};
    const serverUrl = `${PLUGIN_URL}/plugins/register-message`;

    post({
      url: serverUrl,
      body: JSON.stringify(data),
    }).then(([response, responseBody]) => {
      if (response.statusCode !== 200) {
        throw new Error(`Server error ${response.statusCode} at ${serverUrl}: ${responseBody}`);
      }
    }).catch(error => {
      NylasEnv.showErrorDialog(`There was a problem saving your link tracking settings. This message will not have link tracking. ${error.message}`);
      Promise.reject(error);
    });
  }
}

export function activate() {
  ComponentRegistry.register(LinkTrackingButton, {role: 'Composer:ActionButton'});
  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.register(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButton);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.unregister(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess()
}
