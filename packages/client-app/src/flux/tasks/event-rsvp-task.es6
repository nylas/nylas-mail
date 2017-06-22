import Task from './task';
import Event from '../models/event';
import {APIError} from '../errors';
import Utils from '../models/utils';
import DatabaseStore from '../stores/database-store';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';


export default class EventRSVPTask extends Task {
  constructor(event, RSVPEmail, RSVPResponse) {
    super();
    this.event = event;
    this.RSVPEmail = RSVPEmail;
    this.RSVPResponse = RSVPResponse;
  }

  performLocal() {
    return DatabaseStore.inTransaction((t) => {
      return t.find(Event, this.event.id).then((updated) => {
        this.event = updated || this.event;
        this._previousParticipantsState = Utils.deepClone(this.event.participants);

        for (const p of this.event.participants) {
          if (p.email === this.RSVPEmail) {
            p.status = this.RSVPResponse;
          }
        }

        return t.persistModel(this.event);
      })
    });
  }

  onOtherError() {
    return Promise.resolve();
  }

  onTimeoutError() {
    return Promise.resolve();
  }
}
