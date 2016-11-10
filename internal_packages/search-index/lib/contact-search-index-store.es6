import {
  Contact,
  ModelSearchIndexer,
} from 'nylas-exports';

class ContactSearchIndexStore extends ModelSearchIndexer {

  modelClass() { return Contact }

  configKey() { return "contactSearchIndexVersion" }

  INDEX_VERSION() { return 1 }

  getIndexDataForModel(contact) {
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
