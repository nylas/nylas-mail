/* eslint no-cond-assign:0 */
import {MessageViewExtension, RegExpUtils} from 'nylas-exports';

import EmojiStore from './emoji-store';
import emoji from 'node-emoji';

function makeIntoEmojiTag(node, emojiName) {
  node.src = EmojiStore.getImagePath(emojiName);
  node.className = `emoji ${emojiName}`;
  node.width = 14;
  node.height = 14;
  node.style = '';
  node.style.marginTop = '-5px';
}

class EmojiMessageExtension extends MessageViewExtension {
  static renderedMessageBodyIntoDocument({document}) {
    const emojiRegex = RegExpUtils.emojiRegex();

    // special case: Find outlook-style emoji, where it's an image with an emoji alt-text.
    // <img alt="😊" class="EmojiInsert">
    const emojiImageTags = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) => {
        if ((node.nodeName === 'IMG') && node.alt) {
          return NodeFilter.FILTER_ACCEPT;
        }
        return NodeFilter.FILTER_SKIP;
      },
    });

    while (emojiImageTags.nextNode()) {
      const node = emojiImageTags.currentNode;
      const emojiNameForAlt = emoji.which(node.alt);
      if (emojiNameForAlt) {
        makeIntoEmojiTag(node, emojiNameForAlt);
      }
    }

    // general case: look for emoji in the content of text nodes
    const treeWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);

    while (treeWalker.nextNode()) {
      emojiRegex.lastIndex = 0;

      const node = treeWalker.currentNode;
      let match = null;

      while (match = emojiRegex.exec(node.textContent)) {
        const matchEmojiName = emoji.which(match[0]);
        if (matchEmojiName) {
          const matchNode = (match.index === 0) ? node : node.splitText(match.index);
          matchNode.splitText(match[0].length);
          const imageNode = document.createElement('img');
          makeIntoEmojiTag(imageNode, matchEmojiName);
          matchNode.parentNode.replaceChild(imageNode, matchNode);
        }
      }
    }
  }
}

export default EmojiMessageExtension;
