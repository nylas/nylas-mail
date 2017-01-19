import {Event, ModelSearchIndexer} from 'nylas-exports'


const INDEX_VERSION = 1

class EventSearchIndexer extends ModelSearchIndexer {

  get MaxIndexSize() {
    return 5000;
  }

  get ConfigKey() {
    return 'eventSearchIndexVersion';
  }

  get IndexVersion() {
    return INDEX_VERSION;
  }

  get ModelClass() {
    return Event;
  }

  getIndexDataForModel(event) {
    const {title, description, location, participants} = event
    return {
      title,
      location,
      description,
      participants: participants
        .map((c) => `${c.name || ''} ${c.email || ''}`)
        .join(' '),
    }
  }
}

export default new EventSearchIndexer()
