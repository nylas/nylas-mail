import {ComponentRegistry, ExtensionRegistry, DatabaseStore, Message, Actions} from 'nylas-exports';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';
import plugin from '../package.json'

import request from 'request';

const post = Promise.promisify(request.post, {multiArgs: true});
const PLUGIN_ID = plugin.appId;
const PLUGIN_URL = "n1-open-tracking.herokuapp.com";

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

      // set metadata against the message
      Actions.setMetadata(message, PLUGIN_ID, {open_count: 0, open_data: []});

      // post the uid and message id pair to the plugin server
      const data = {uid: uid, message_id: message.id, thread_id: 1};
      const serverUrl = `http://${PLUGIN_URL}/register-message`;
      return post({
        url: serverUrl,
        body: JSON.stringify(data),
      }).then(([response, responseBody]) => {
        if (response.statusCode !== 200) {
          throw new Error();
        }
        return responseBody;
      }).catch(error => {
        NylasEnv.showErrorDialog("There was a problem contacting the Open Tracking server! This message will not have open tracking :(");
        Promise.reject(error);
      });
    }
  });
}

export function activate() {
  ComponentRegistry.register(OpenTrackingButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(OpenTrackingIcon, {role: 'ThreadListIcon'});
  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButton);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess()
}
