import request from 'request';
import {Actions} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './link-tracking-constants'

export default class LinkTrackingAfterSend {
  static post = Promise.promisify(request.post, {multiArgs: true});

  static afterDraftSend({message}) {
    // only run this handler in the main window
    if (!NylasEnv.isMainWindow()) return;

    // grab message metadata, if any
    const metadata = message.metadataForPluginId(PLUGIN_ID);
    if (metadata && metadata.uid) {
      // get the uid from the metadata, if present
      const uid = metadata.uid;

      // post the uid and message id pair to the plugin server
      const data = {uid: uid, message_id: message.id};
      const serverUrl = `${PLUGIN_URL}/plugins/register-message`;

      LinkTrackingAfterSend.post({
        url: serverUrl,
        body: JSON.stringify(data),
      }).then(([response, responseBody]) => {
        if (response.statusCode !== 200) {
          throw new Error(`Server error ${response.statusCode} at ${serverUrl}: ${responseBody}`);
        }
      }).catch(error => {
        NylasEnv.showErrorDialog(`There was a problem saving your link tracking settings. This message will not have link tracking. ${error.message}`);
        // clear metadata - link tracking won't work for this message.
        Actions.setMetadata(message, PLUGIN_ID, null);
        Promise.reject(error);
      });
    }
  }
}

