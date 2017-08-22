import {ComposerExtension, RegExpUtils} from 'nylas-exports';
import {PLUGIN_ID, PLUGIN_URL} from './link-tracking-constants'

function forEachATagInBody(draftBodyRootNode, callback) {
  const treeWalker = document.createTreeWalker(draftBodyRootNode, NodeFilter.SHOW_ELEMENT, {
    acceptNode: (node) => {
      if (node.classList.contains('gmail_quote')) {
        return NodeFilter.FILTER_REJECT; // skips the entire subtree
      }
      return (node.hasAttribute('href')) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP;
    },
  })

  while (treeWalker.nextNode()) {
    callback(treeWalker.currentNode);
  }
}

/**
 * This replaces all links with a new url that redirects through our
 * cloud-api servers (see cloud-api/routes/link-tracking)
 *
 * This redirect link href is NOT complete at this stage. It requires
 * substantial post processing just before send. This happens in iso-core
 * since sending can happen immediately or later in cloud-workers.
 *
 * See isomorphic-core tracking-utils.es6
 *
 * We don't have a Message Id yet since this is still a draft. We generate
 * and replace `MESSAGE_ID` later with the correct one.
 *
 * We also need to add individualized recipients to each tracking pixel
 * for each message sent to each person.
 *
 * We finally need to put the original url back for the message that ends
 * up in the users's sent folder. This ensures the sender doesn't trip
 * their own link tracks.
 */
export default class LinkTrackingComposerExtension extends ComposerExtension {
  static applyTransformsForSending({draftBodyRootNode, draft}) {
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      const messageUid = draft.clientId;
      const links = [];

      forEachATagInBody(draftBodyRootNode, (el) => {
        const url = el.getAttribute('href');
        if (!RegExpUtils.urlRegex().test(url)) {
          return;
        }
        const encoded = encodeURIComponent(url);
        const redirectUrl = `${PLUGIN_URL}/link/MESSAGE_ID/${links.length}?redirect=${encoded}`;

        links.push({
          url,
          click_count: 0,
          click_data: [],
          redirect_url: redirectUrl,
        });

        el.setAttribute('href', redirectUrl);
      });

      // save the link info to draft metadata
      metadata.uid = messageUid;
      metadata.links = links;
      draft.applyPluginMetadata(PLUGIN_ID, metadata);
    }
  }

  static unapplyTransformsForSending({draftBodyRootNode}) {
    forEachATagInBody(draftBodyRootNode, (el) => {
      const url = el.getAttribute('href');
      if (url.indexOf(PLUGIN_URL) !== -1) {
        const userURLEncoded = url.split('?redirect=')[1];
        el.setAttribute('href', decodeURIComponent(userURLEncoded));
      }
    });
  }
}
