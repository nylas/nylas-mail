import {Rx, CalendarDataSource} from 'nylas-exports'
import ProposedTimeCalendarStore from '../proposed-time-calendar-store'

export default class ProposedTimeCalendarDataSource extends CalendarDataSource {
  buildObservable({startTime, endTime, disabledCalendars}) {
    this.observable = Rx.Observable.combineLatest([
      super.buildObservable({startTime, endTime, disabledCalendars}),
      Rx.Observable.fromStore(ProposedTimeCalendarStore).map((store) => store.proposalsAsEvents()),
    ])
    .map(([superResult, proposedTimes]) => {
      return {events: superResult.events.concat(proposedTimes)}
    })
    return this.observable;
  }
}
