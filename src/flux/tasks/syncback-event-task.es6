import {Event} from 'nylas-exports';
import SyncbackModelTask from './syncback-model-task'

const EVENTS_ENDPOINT = "/events"

export default class SyncbackEventTask extends SyncbackModelTask {
  constructor(clientId) {
    super({clientId, endpoint: EVENTS_ENDPOINT})
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
