// import Rx from 'rx-lite-testing'
import {events} from './fixtures/events'
import {CalendarDataSource} from 'nylas-exports'

export default class TestDataSource extends CalendarDataSource {
  buildObservable({startTime, endTime}) {
    this.endTime = endTime;
    this.startTime = startTime;
    return this
  }

  subscribe(onNext) {
    onNext({events})
    this.unsubscribe = jasmine.createSpy("unusbscribe");
    return {dispose: this.unsubscribe}
  }
}
