import {ComposerExtension} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants';

export default class OpenTrackingComposerExtension extends ComposerExtension {

  /**
   * This inserts a placeholder image tag to serve as our open tracking
   * pixel.
   *
   * See cloud-api/routes/open-tracking
   *
   * This image tag is NOT complete at this stage. It requires substantial
   * post processing just before send. This happens in iso-core since
   * sending can happen immediately or later in cloud-workers.
   *
   * See isomorphic-core tracking-utils.es6
   *
   * We don't add a `src` parameter here since we don't want the tracking
   * pixel to prematurely load with an incorrect url.
   *
   * We also don't have a Message Id yet since this is still a draft. We
   * generate and replace `MESSAGE_ID` later with the correct one.
   *
   * We also need to add individualized recipients to each tracking pixel
   * for each message sent to each person.
   *
   * We finally need to remove the tracking pixel from the message that
   * ends up in the users's sent folder. This ensures the sender doesn't
   * trip their own open track.
   */
  static applyTransformsForSending({draftBodyRootNode, draft}) {
    // grab message metadata, if any
    const messageUid = draft.clientId;
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (!metadata) {
      return;
    }

    // insert a tracking pixel <img> into the message
    const serverUrl = `${PLUGIN_URL}/open/MESSAGE_ID`
    const imgFragment = document.createRange().createContextualFragment(`<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" data-open-tracking-src="${serverUrl}">`);
    const beforeEl = draftBodyRootNode.querySelector('.gmail_quote');
    if (beforeEl) {
      beforeEl.parentNode.insertBefore(imgFragment, beforeEl);
    } else {
      draftBodyRootNode.appendChild(imgFragment);
    }

    // save the uid info to draft metadata
    metadata.uid = messageUid;
    draft.applyPluginMetadata(PLUGIN_ID, metadata);
  }

  static unapplyTransformsForSending({draftBodyRootNode}) {
    const imgEl = draftBodyRootNode.querySelector('.n1-open');
    if (imgEl) {
      imgEl.parentNode.removeChild(imgEl);
    }
  }
}
