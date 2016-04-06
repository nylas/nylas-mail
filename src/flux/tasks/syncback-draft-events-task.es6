import Task from './task';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import BaseDraftTask from './base-draft-task';
import DatabaseStore from '../stores/database-store';
import Event from '../models/event';

export default class SyncbackDraftEventsTask extends BaseDraftTask {

  constructor(draftClientId) {
    super(draftClientId);
    this._appliedEvents = null;
  }

  label() {
    return "Creating meeting request...";
  }

  performRemote() {
    return this.refreshDraftReference()
    .then(this.uploadEvents)
    .then(this.applyChangesToDraft)
    .thenReturn(Task.Status.Success)
    .catch((err) => {
      if (err instanceof BaseDraftTask.DraftNotFoundError) {
        return Promise.resolve(Task.Status.Continue);
      }
      if (err instanceof APIError && !NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }

  uploadEvents = () => {
    const events = this.draft.events;
    if (events && events.length) {
      const event = events[0];  // only upload one
      return this.uploadEvent(event).then((savedEvent) => {
        if (savedEvent) {
          this._appliedEvents = [savedEvent];
        }
        Promise.resolve();
      });
    }
    return Promise.resolve()
  };

  uploadEvent = (event) => {
    return NylasAPI.makeRequest({
      path: "/events?notify_participants=true",
      accountId: this.draft.accountId,
      method: "POST",
      body: this._prepareEventJson(event),
      returnsModel: true,
    }).then(json =>{
      return (new Event()).fromJSON(json);
    });
  };

  _prepareEventJson(inEvent) {
    const event = inEvent.fromDraft(this.draft)
    const json = event.toJSON();
    delete json.id;
    json.when = {
      start_time: json._start,
      end_time: json._end,
    };

    return json;
  }

  applyChangesToDraft = () => {
    return DatabaseStore.inTransaction((t) => {
      return this.refreshDraftReference().then(() => {
        this.draft.events = this._appliedEvents;
        return t.persistModel(this.draft);
      });
    });
  }
}
