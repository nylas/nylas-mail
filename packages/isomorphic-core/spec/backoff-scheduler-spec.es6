import {BackoffScheduler, ExponentialBackoffScheduler} from '../src/backoff-schedulers'


describe('BackoffSchedulers', function describeBlock() {
  describe('BackoffScheduler', () => {
    function linearBackoff(base, numTries) {
      return base * numTries
    }

    it('calculates the next delay correctly with no jitter', () => {
      const scheduler = new BackoffScheduler({
        jitter: false,
        baseDelay: 2,
        maxDelay: 5,
        getNextBackoffDelay: linearBackoff,
      })
      expect(scheduler.nextDelay()).toEqual(0)
      expect(scheduler.nextDelay()).toEqual(2)
      expect(scheduler.nextDelay()).toEqual(4)
      expect(scheduler.nextDelay()).toEqual(5)
      expect(scheduler.nextDelay()).toEqual(5)
    })

    it('calculates the next delay correctly with jitter', () => {
      spyOn(Math, 'random').andReturn(0.5)
      const scheduler = new BackoffScheduler({
        jitter: true,
        baseDelay: 2,
        maxDelay: 5,
        getNextBackoffDelay: linearBackoff,
      })
      expect(scheduler.nextDelay()).toEqual(0)
      expect(scheduler.nextDelay()).toEqual(1)
      expect(scheduler.nextDelay()).toEqual(2)
      expect(scheduler.nextDelay()).toEqual(3)
      expect(scheduler.nextDelay()).toEqual(4)
      expect(scheduler.nextDelay()).toEqual(5)
      expect(scheduler.nextDelay()).toEqual(5)
    })
  });

  describe('ExponentialBackoffScheduler', () => {
    it('calculates the next delay correctly with no jitter', () => {
      const scheduler = new ExponentialBackoffScheduler({
        jitter: false,
        baseDelay: 2,
        maxDelay: 10,
      })
      expect(scheduler.nextDelay()).toEqual(2)
      expect(scheduler.nextDelay()).toEqual(4)
      expect(scheduler.nextDelay()).toEqual(8)
      expect(scheduler.nextDelay()).toEqual(10)
      expect(scheduler.nextDelay()).toEqual(10)
    })

    it('calculates the next delay correctly with no jitter', () => {
      spyOn(Math, 'random').andReturn(0.5)
      const scheduler = new ExponentialBackoffScheduler({
        jitter: true,
        baseDelay: 2,
        maxDelay: 10,
      })
      expect(scheduler.nextDelay()).toEqual(1)
      expect(scheduler.nextDelay()).toEqual(2)
      expect(scheduler.nextDelay()).toEqual(4)
      expect(scheduler.nextDelay()).toEqual(8)
      expect(scheduler.nextDelay()).toEqual(10)
      expect(scheduler.nextDelay()).toEqual(10)
    })
  });
});
