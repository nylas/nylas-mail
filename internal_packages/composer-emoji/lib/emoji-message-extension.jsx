import {MessageViewExtension} from 'nylas-exports';


class EmojiMessageExtension extends MessageViewExtension {
  static formatMessageBody({message}) {
    message.body = message.body.replace(/<span class="broken-emoji ([a-zA-Z0-9-_]*)">.*<\/span>/g, (match, emojiName) =>
      `<span class="missing-emoji ${emojiName}"><img src="images/composer-emoji/missing-emoji/${emojiName}.png" width="14" height="14" style="margin-top: -5px;" /></span>`
    );
  }
}

export default EmojiMessageExtension;
