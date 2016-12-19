import {ComposerExtension} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants';

export default class OpenTrackingComposerExtension extends ComposerExtension {

  static applyTransformsForSending({draftBodyRootNode, draft}) {
    // grab message metadata, if any
    const messageUid = draft.clientId;
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (!metadata) {
      return;
    }

    // insert a tracking pixel <img> into the message
    const serverUrl = `${PLUGIN_URL}/open/MESSAGE_ID`
    const imgFragment = document.createRange().createContextualFragment(`<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${serverUrl}">`);
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
