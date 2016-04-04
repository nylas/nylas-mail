import Rx from 'rx-lite'
import Event from '../../flux/models/event'
import Matcher from '../../flux/attributes/matcher'
import DatabaseStore from '../../flux/stores/database-store'

export default class CalendarDataSource {
  buildObservable({startTime, endTime}) {
    const end = Event.attributes.end
    const start = Event.attributes.start

    const matcher = new Matcher.Or([
      new Matcher.And([start.lte(endTime), end.gte(startTime)]),
      new Matcher.And([start.lte(endTime), start.gte(startTime)]),
      new Matcher.And([end.gte(startTime), end.lte(endTime)]),
      new Matcher.And([end.gte(endTime), start.lte(startTime)]),
    ]);

    const query = DatabaseStore.findAll(Event).where(matcher)
    this.observable = Rx.Observable.fromQuery(query)
    return this.observable
  }

  subscribe(callback) {
    return this.observable.subscribe(callback)
  }
}
