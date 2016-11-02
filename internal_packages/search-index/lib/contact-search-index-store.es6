import {
  Contact,
  DatabaseStore,
} from 'nylas-exports';

const INDEX_VERSION = 1;

class ContactSearchIndexStore {
  constructor() {
    this.unsubscribers = []
  }

  activate() {
    this.initializeIndex();
    this.unsubscribers = [
      DatabaseStore.listen(this.onDataChanged),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  initializeIndex() {
    if (NylasEnv.config.get('contactSearchIndexVersion') !== INDEX_VERSION) {
      DatabaseStore.dropSearchIndex(Contact)
      .then(() => DatabaseStore.createSearchIndex(Contact))
      .then(() => this.buildIndex())
    }
  }

  buildIndex(offset = 0) {
    const indexingPageSize = 1000;
    const indexingPageDelay = 1000;

    DatabaseStore.findAll(Contact).limit(indexingPageSize).offset(offset).then((contacts) => {
      if (contacts.length === 0) {
        NylasEnv.config.set('contactSearchIndexVersion', INDEX_VERSION)
        return;
      }
      Promise.each(contacts, (contact) => {
        return DatabaseStore.indexModel(contact, this.getIndexDataForContact(contact))
      }).then(() => {
        setTimeout(() => {
          this.buildIndex(offset + contacts.length);
        }, indexingPageDelay);
      });
    });
  }

  /**
   * When a contact gets updated we will update the search index with the data
   * from that contact if the account it belongs to is not being currently
   * synced.
   *
   * When the account is successfully synced, its contacts will be added to the
   * index either via `onAccountsChanged` or via `initializeIndex` when the app
   * starts
   */
  onDataChanged = (change) => {
    if (change.objectClass !== Contact.name) {
      return;
    }

    change.objects.forEach((contact) => {
      if (change.type === 'persist') {
        DatabaseStore.indexModel(contact, this.getIndexDataForContact(contact))
      } else {
        DatabaseStore.unindexModel(contact)
      }
    });
  }

  getIndexDataForContact(contact) {
    return {
      content: [
        contact.name ? contact.name : '',
        contact.email ? contact.email : '',
        contact.email ? contact.email.replace('@', ' ') : '',
      ].join(' '),
    };
  }

}

export default new ContactSearchIndexStore()
