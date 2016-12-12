import {React, MessageViewExtension, Actions} from 'nylas-exports'
import LinkTrackingMessagePopover from './link-tracking-message-popover'
import {PLUGIN_ID} from './link-tracking-constants'

export default class LinkTrackingMessageExtension extends MessageViewExtension {

  static renderedMessageBodyIntoDocument({document, message, iframe}) {
    const metadata = message.metadataForPluginId(PLUGIN_ID) || {};
    if ((metadata.links || []).length === 0) { return }

    const links = {}
    for (const link of metadata.links) {
      links[link.url] = link
      links[link.redirect_url] = link
    }

    const trackedLinksWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) => {
        if ((node.nodeName === 'A') && links[node.getAttribute('href')]) {
          return NodeFilter.FILTER_ACCEPT;
        }
        return NodeFilter.FILTER_SKIP;
      },
    });

    while (trackedLinksWalker.nextNode()) {
      const node = trackedLinksWalker.currentNode;
      const nodeHref = node.getAttribute('href');
      const originalHref = links[nodeHref].url;

      const dotNode = document.createElement('img');
      dotNode.className = 'link-tracking-dot';
      dotNode.style = 'margin-bottom: 0.75em; margin-left: 1px; margin-right: 1px; vertical-align: text-bottom; width: 6px;';
      if (links[nodeHref].click_count > 0) {
        dotNode.title = `${links[nodeHref].click_count} click${links[nodeHref].click_count === 1 ? "" : "s"} (${originalHref})`;
        dotNode.src = 'nylas://link-tracking/assets/ic-tracking-visited@2x.png';
        dotNode.style = 'margin-bottom: 0.75em; margin-left: 1px; margin-right: 1px; vertical-align: text-bottom; width: 6px; cursor: pointer;'
        dotNode.onmousedown = () => {
          const dotRect = dotNode.getBoundingClientRect();
          const iframeRect = iframe.getBoundingClientRect();
          const rect = {
            top: dotRect.top + iframeRect.top,
            bottom: dotRect.bottom + iframeRect.top,
            left: dotRect.left + iframeRect.left,
            right: dotRect.right + iframeRect.left,
            width: dotRect.width,
            height: dotRect.height,
          };
          Actions.openPopover(
            <LinkTrackingMessagePopover
              message={message}
              linkMetadata={links[nodeHref]}
            />,
            {
              originRect: rect,
              direction: 'down',
            }
          );
        }
      } else {
        dotNode.title = `This link has not been clicked (${originalHref})`;
        dotNode.src = 'nylas://link-tracking/assets/ic-tracking-unvisited@2x.png';
      }
      node.href = originalHref;
      node.title = originalHref;
      node.parentNode.insertBefore(dotNode, node.nextSibling);
    }
  }
}
