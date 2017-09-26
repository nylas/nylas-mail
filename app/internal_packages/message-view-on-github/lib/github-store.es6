import _ from 'underscore';
import MailspringStore from 'mailspring-store';
import { MessageStore } from 'mailspring-exports';

class GithubStore extends MailspringStore {
  // It's very common practive for {MailspringStore}s to listen to other parts of N1.
  // Since Stores are singletons and constructed once on `require`, there is no
  // teardown step to turn off listeners.
  constructor() {
    super();
    this.listenTo(MessageStore, this._onMessageStoreChanged);
  }

  // This is the only public method on `GithubStore` and it's read only.
  // All {MailspringStore}s ONLY have reader methods. No setter methods. Use an
  // `Action` instead!
  //
  // This is the computed & cached value that our `ViewOnGithubButton` will
  // render.
  link() {
    return this._link;
  }

  // Private methods

  _onMessageStoreChanged() {
    if (!MessageStore.threadId()) {
      return;
    }

    const itemIds = _.pluck(MessageStore.items(), 'id');
    if (itemIds.length === 0 || _.isEqual(itemIds, this._lastItemIds)) {
      return;
    }

    this._lastItemIds = itemIds;
    this._link = this._isRelevantThread() ? this._findGitHubLink() : null;
    this.trigger();
  }

  _findGitHubLink() {
    let msg = MessageStore.items()[0];
    if (!msg.body) {
      // The msg body may be null if it's collapsed. In that case, use the
      // last message. This may be less relaiable since the last message
      // might be a side-thread that doesn't contain the link in the quoted
      // text.
      msg = _.last(MessageStore.items());
    }

    // Use a regex to parse the message body for GitHub URLs - this is a quick
    // and dirty method to determine the GitHub object the email is about:
    // https://regex101.com/r/aW8bI4/2
    const re = /<a.*?href=['"](.*?)['"].*?view.*?it.*?on.*?github.*?\/a>/gim;
    const firstMatch = re.exec(msg.body);
    if (firstMatch) {
      // [0] is the full match and [1] is the matching group
      return firstMatch[1];
    }

    return null;
  }

  _isRelevantThread() {
    const participants = MessageStore.thread().participants || [];
    const githubDomainRegex = /@github\.com/gi;
    return participants.some(contact => githubDomainRegex.test(contact.email));
  }
}

/*
IMPORTANT NOTE:

All {MailspringStore}s are constructed upon their first `require` by another
module.  Since `require` is cached, they are only constructed once and
are therefore singletons.
*/
export default new GithubStore();
