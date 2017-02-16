import {CalendarDataSource} from 'nylas-exports'
import ProposedTimeCalendarStore from '../lib/proposed-time-calendar-store'

export default class TestProposalDataSource extends CalendarDataSource {
  buildObservable({startTime, endTime}) {
    this.endTime = endTime
    this.startTime = startTime
    this._usub = ProposedTimeCalendarStore.listen(this.manuallyTrigger)
    return this
  }

  manuallyTrigger = () => {
    this.onNext({events: ProposedTimeCalendarStore.proposalsAsEvents()})
  }

  subscribe(onNext) {
    this.onNext = onNext
    this.manuallyTrigger()
    const dispose = () => {
      this._usub()
    }
    return {dispose}
  }
}
