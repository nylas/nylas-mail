import { Event } from 'mailspring-exports';

export default class SyncbackEventTask {
  constructor() {
    // id
    throw new Error('Unimplemented!');
    // super({id, endpoint: EVENTS_ENDPOINT})
  }

  getModelConstructor() {
    return Event;
  }

  // Removes the 'object' field from the event's 'when' data. This is only
  // necessary because the current events API doesn't accept requests
  // when this field is defined.
  getRequestData(model) {
    const data = super.getRequestData(model);
    delete data.body.when.object;
    return data;
  }
}
