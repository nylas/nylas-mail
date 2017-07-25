import { ModelSearchIndexer } from 'nylas-exports';
import SalesforceObject from '../models/salesforce-object'

class SalesforceSearchIndexer extends ModelSearchIndexer {

  get MaxIndexSize() {
    return 10000
  }

  get ConfigKey() {
    return "salesforce.searchIndexVersion"
  }

  get IndexVersion() {
    return 1
  }

  get ModelClass() {
    return SalesforceObject
  }

  getIndexDataForModel(sObject) {
    return {
      content: [
        sObject.name ? sObject.name : '',
        sObject.identifier ? sObject.identifier : '',
        sObject.identifier ? sObject.identifier.replace('@', ' ') : '',
      ].join(' '),
    };
  }
}

export default new SalesforceSearchIndexer()
