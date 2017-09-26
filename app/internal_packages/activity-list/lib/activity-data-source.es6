import { Rx, Message, DatabaseStore } from 'mailspring-exports';

export default class ActivityDataSource {
  buildObservable({ openTrackingId, linkTrackingId, messageLimit }) {
    const query = DatabaseStore.findAll(Message)
      .order(Message.attributes.date.descending())
      .where(Message.attributes.pluginMetadata.contains(openTrackingId, linkTrackingId))
      .limit(messageLimit);
    this.observable = Rx.Observable.fromQuery(query);
    return this.observable;
  }

  subscribe(callback) {
    return this.observable.subscribe(callback);
  }
}
