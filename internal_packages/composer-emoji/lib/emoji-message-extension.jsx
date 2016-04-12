import {MessageViewExtension, RegExpUtils} from 'nylas-exports';

import EmojiStore from './emoji-store';
import emoji from 'node-emoji';


class EmojiMessageExtension extends MessageViewExtension {
  static formatMessageBody({message}) {
    message.body = message.body.replace(RegExpUtils.emojiRegex(), (match) =>
      `<img class="emoji ${emoji.which(match)}" src="${EmojiStore.getImagePath(emoji.which(match))}" width="14" height="14" style="margin-top: -5px;">`
    );
  }
}

export default EmojiMessageExtension;
