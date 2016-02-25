import request from 'request';
import {ComponentRegistry, DatabaseStore, Message, ExtensionRegistry, Actions} from 'nylas-exports';
import LinkTrackingButton from './link-tracking-button';
// TODO what's up with these components?
// import LinkTrackingIcon from './link-tracking-icon';
// import LinkTrackingPanel from './link-tracking-panel';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingMessageExtension from './link-tracking-message-extension';
import {PLUGIN_ID, PLUGIN_URL} from './link-tracking-constants';

const post = Promise.promisify(request.post, {multiArgs: true});


function afterDraftSend({draftClientId}) {
  // only run this handler in the main window
  if (!NylasEnv.isMainWindow()) return;

  // query for the message
  DatabaseStore.findBy(Message, {clientId: draftClientId}).then((message) => {
    // grab message metadata, if any
    const metadata = message.metadataForPluginId(PLUGIN_ID);
    // get the uid from the metadata, if present
    if (metadata) {
      const uid = metadata.uid;

      // post the uid and message id pair to the plugin server
      const data = {uid: uid, message_id: message.id};
      const serverUrl = `${PLUGIN_URL}/plugins/register-message`;
      return post({
        url: serverUrl,
        body: JSON.stringify(data),
      }).then( ([response, responseBody]) => {
        if (response.statusCode !== 200) {
          throw new Error(`Link Tracking server error ${response.statusCode} at ${serverUrl}: ${responseBody}`);
        }
        return responseBody;
      }).catch(error => {
        NylasEnv.showErrorDialog("There was a problem contacting the Link Tracking server! This message will not have link tracking");
        Promise.reject(error);
      });
    }
  });
}

export function activate() {
  ComponentRegistry.register(LinkTrackingButton, {role: 'Composer:ActionButton'});
  // ComponentRegistry.register(LinkTrackingIcon, {role: 'ThreadListIcon'});
  // ComponentRegistry.register(LinkTrackingPanel, {role: 'message:BodyHeader'});
  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.register(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButton);
  // ComponentRegistry.unregister(LinkTrackingIcon);
  // ComponentRegistry.unregister(LinkTrackingPanel);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.unregister(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess()
}
