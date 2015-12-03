import {AccountStore, Actions} from 'nylas-exports';
import PrintWindow from './print-window';

class Printer {

  constructor() {
    this.unsub = Actions.printThread.listen(this._printThread);
  }

  _printThread(thread, htmlContent) {
    if (!thread) throw new Error('Printing: No thread active!');

    // Get the <nylas-styles> tag present in the document
    const styleTag = document.getElementsByTagName('nylas-styles')[0];
    // These iframes should correspond to the message iframes when a thread is
    // focused
    const iframes = document.getElementsByTagName('iframe');
    // Grab the html inside the iframes
    const messagesHtml = [].slice.call(iframes).map((iframe)=> {
      return iframe.contentDocument.documentElement.innerHTML;
    });

    const win = new PrintWindow({
      subject: thread.subject,
      account: {
        name: AccountStore.current().name,
        email: AccountStore.current().emailAddress,
      },
      participants: thread.participants,
      styleTags: styleTag.innerHTML,
      htmlContent,
      printMessages: JSON.stringify(messagesHtml),
    });
    win.load();
  }

  deactivate() {
    this.unsub();
  }
}

export default Printer;
