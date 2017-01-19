import {
  Contact,
  ModelSearchIndexer,
} from 'nylas-exports';


const INDEX_VERSION = 1;

class ContactSearchIndexer extends ModelSearchIndexer {

  get MaxIndexSize() {
    return 5000;
  }

  get ModelClass() {
    return Contact;
  }

  get ConfigKey() {
    return "contactSearchIndexVersion";
  }

  get IndexVersion() {
    return INDEX_VERSION;
  }

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

export default new ContactSearchIndexer()
