import AutoloadImagesStore from './autoload-images-store';
import {MessageViewExtension} from 'nylas-exports';

export default class AutoloadImagesExtension extends MessageViewExtension {
  static formatMessageBody = ({message})=> {
    if (AutoloadImagesStore.shouldBlockImagesIn(message)) {
      message.body = message.body.replace(AutoloadImagesStore.ImagesRegexp, (match, prefix)=> {
        return `${prefix}#`;
      });
    }
  }
}
