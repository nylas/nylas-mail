import _ from 'underscore';
import Rx from 'rx-lite';
import MailspringStore from 'mailspring-store';

import Utils from '../models/utils';
import Thread from '../models/thread';
import Actions from '../actions';
import Contact from '../models/contact';
import MessageStore from './message-store';
import AccountStore from './account-store';
import DatabaseStore from './database-store';
import SearchQueryParser from '../../services/search/search-query-parser';

// A store that handles the focuses collections of and individual contacts
class FocusedContactsStore extends MailspringStore {
  constructor() {
    super();
    this.listenTo(MessageStore, this._onMessageStoreChanged);
    this.listenTo(Actions.focusContact, this._onFocusContact);
    this._clearCurrentParticipants();
    this._triggerLater = _.debounce(this.trigger, 250);
    this._loadCurrentParticipantThreads = _.debounce(this._loadCurrentParticipantThreads, 250);
  }

  sortedContacts() {
    return this._currentContacts;
  }

  focusedContact() {
    return this._currentFocusedContact;
  }

  focusedContactThreads() {
    return this._currentParticipantThreads || [];
  }

  // We need to wait now for the MessageStore to grab all of the
  // appropriate messages for the given thread.

  _onMessageStoreChanged = () => {
    const threadId = MessageStore.itemsLoading() ? null : MessageStore.threadId();

    // Always clear data immediately when we're showing the wrong thread
    if (this._currentThread && this._currentThread.id !== threadId) {
      this._clearCurrentParticipants();
      this.trigger();
    }

    // Wait to populate until the user has stopped moving through threads. This is
    // important because the FocusedContactStore powers tons of third-party extensions,
    // which could do /horrible/ things when we trigger.
    const thread = MessageStore.itemsLoading() ? null : MessageStore.thread();
    if (thread && thread.id !== (this._currentThread || {}).id) {
      this._currentThread = thread;
      this._populateCurrentParticipants();
    }
  };

  // For now we take the last message
  _populateCurrentParticipants() {
    this._scoreAllParticipants();
    const sorted = _.sortBy(Object.values(this._contactScores), 'score').reverse();
    this._currentContacts = sorted.map(obj => obj.contact);
    return this._onFocusContact(this._currentContacts[0]);
  }

  _clearCurrentParticipants() {
    if (this._unsubFocusedContact) {
      this._unsubFocusedContact.dispose();
      this._unsubFocusedContact = null;
    }
    this._contactScores = {};
    this._currentContacts = [];
    this._unsubFocusedContact = null;
    this._currentFocusedContact = null;
    this._currentThread = null;
    this._currentParticipantThreads = [];
  }

  _onFocusContact = contact => {
    if (this._unsubFocusedContact) {
      this._unsubFocusedContact.dispose();
      this._unsubFocusedContact = null;
    }

    this._currentParticipantThreads = [];

    if (contact && contact.email) {
      const query = DatabaseStore.findBy(Contact, {
        accountId: this._currentThread.accountId,
        email: contact.email,
      });
      this._unsubFocusedContact = Rx.Observable.fromQuery(query).subscribe(match => {
        if (match) {
          match.name = contact.name; // always show the name from the current email
        }
        this._currentFocusedContact = match || contact;
        this._triggerLater();
      });
      this._loadCurrentParticipantThreads();
    } else {
      this._currentFocusedContact = null;
      this._triggerLater();
    }
  };

  _loadCurrentParticipantThreads() {
    const currentContact = this._currentFocusedContact || {};
    const email = currentContact.email;
    if (!email) {
      return;
    }
    DatabaseStore.findAll(Thread)
      .structuredSearch(SearchQueryParser.parse(`from:${email}`))
      .limit(100)
      .background()
      .then((threads = []) => {
        if (currentContact.email !== email) {
          return;
        }
        this._currentParticipantThreads = threads;
        this.trigger();
      });
  }

  // We score everyone to determine who's the most relevant to display in
  // the sidebar.
  _scoreAllParticipants() {
    const score = (message, msgNum, field, multiplier) => {
      (message[field] || []).forEach((contact, j) => {
        const bonus = message[field].length - j;
        this._assignScore(contact, (msgNum + 1) * multiplier + bonus);
      });
    };

    const iterable = MessageStore.items();
    for (let msgNum = iterable.length - 1; msgNum >= 0; msgNum--) {
      const message = iterable[msgNum];
      if (message.draft) {
        score(message, msgNum, 'to', 10000);
        score(message, msgNum, 'cc', 1000);
      } else {
        score(message, msgNum, 'from', 100);
        score(message, msgNum, 'to', 10);
        score(message, msgNum, 'cc', 1);
      }
    }

    return this._contactScores;
  }

  // Self always gets a score of 0
  _assignScore(contact, score = 0) {
    if (!contact || !contact.email) {
      return;
    }
    if (contact.email.trim().length === 0) {
      return;
    }

    const key = Utils.toEquivalentEmailForm(contact.email);

    if (!this._contactScores[key]) {
      this._contactScores[key] = {
        contact: contact,
        score: score - this._calculatePenalties(contact, score),
      };
    }
  }

  _calculatePenalties(contact, score) {
    let penalties = 0;
    const email = contact.email.toLowerCase().trim();

    const accountId = (this._currentThread || {}).accountId;
    const account = AccountStore.accountForId(accountId) || {};
    const myEmail = account.emailAddress;

    if (email === myEmail) {
      // The whole thing which will penalize to zero
      penalties += score;
    }

    const notCommonDomain = !Utils.emailHasCommonDomain(myEmail);
    const sameDomain = Utils.emailsHaveSameDomain(myEmail, email);
    if (notCommonDomain && sameDomain) {
      penalties += score * 0.9;
    }

    return Math.max(penalties, 0);
  }
}

export default new FocusedContactsStore();
