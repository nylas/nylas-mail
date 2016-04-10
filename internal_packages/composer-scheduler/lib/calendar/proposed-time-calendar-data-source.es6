import Rx from 'rx-lite'
import {CalendarDataSource} from 'nylas-exports'
import ProposedTimeCalendarStore from '../proposed-time-calendar-store'

export default class ProposedTimeCalendarDataSource extends CalendarDataSource {
  buildObservable({startTime, endTime}) {
    const $events = super.buildObservable({startTime, endTime});
    const $proposedTimes = Rx.Observable.fromStore(ProposedTimeCalendarStore)
      .map((store) => store.timeBlocksAsEvents())
    const $obs = Rx.Observable.combineLatest([$events, $proposedTimes])
      .map(([calEvents, proposedTimes]) => {
        return {events: calEvents.concat(proposedTimes)}
      })
    this.observable = $obs;
    return $obs;
  }
}
