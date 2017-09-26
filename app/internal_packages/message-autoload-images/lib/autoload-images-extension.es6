import { MessageViewExtension } from 'mailspring-exports';
import AutoloadImagesStore from './autoload-images-store';

export default class AutoloadImagesExtension extends MessageViewExtension {
  static formatMessageBody = ({ message }) => {
    if (AutoloadImagesStore.shouldBlockImagesIn(message)) {
      message.body = message.body.replace(AutoloadImagesStore.ImagesRegexp, (match, prefix) => {
        return `${prefix}#`;
      });
    }
  };
}
