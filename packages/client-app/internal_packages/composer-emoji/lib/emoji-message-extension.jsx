/* eslint no-cond-assign:0 */
import {MessageViewExtension, RegExpUtils} from 'nylas-exports';
import emoji from 'node-emoji';

import EmojiStore from './emoji-store';

function makeIntoEmojiTag(nodeArg, emojiName) {
  const node = nodeArg;
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

    // Look for emoji in the content of text nodes
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
