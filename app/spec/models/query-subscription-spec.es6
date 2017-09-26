import DatabaseStore from '../../src/flux/stores/database-store';

import QueryRange from '../../src/flux/models/query-range';
import MutableQueryResultSet from '../../src/flux/models/mutable-query-result-set';
import QuerySubscription from '../../src/flux/models/query-subscription';
import Thread from '../../src/flux/models/thread';
import Utils from '../../src/flux/models/utils';

describe('QuerySubscription', function QuerySubscriptionSpecs() {
  describe('constructor', () =>
    describe('when a query is provided', () => {
      it('should finalize the query', () => {
        const query = DatabaseStore.findAll(Thread);
        const subscription = new QuerySubscription(query);
        expect(subscription).toBeDefined();
        expect(query._finalized).toBe(true);
      });

      it('should throw an exception if the query is a count query, which cannot be observed', () => {
        const query = DatabaseStore.count(Thread);
        expect(() => {
          const subscription = new QuerySubscription(query);
          return subscription;
        }).toThrow();
      });

      it('should call `update` to initialize the result set', () => {
        const query = DatabaseStore.findAll(Thread);
        spyOn(QuerySubscription.prototype, 'update');
        const subscription = new QuerySubscription(query);
        expect(subscription).toBeDefined();
        expect(QuerySubscription.prototype.update).toHaveBeenCalled();
      });

      describe('when initialModels are provided', () =>
        it('should apply the models and trigger', () => {
          const query = DatabaseStore.findAll(Thread);
          const threads = [1, 2, 3, 4, 5].map(i => new Thread({ id: i }));
          const subscription = new QuerySubscription(query, { initialModels: threads });
          expect(subscription._set).not.toBe(null);
        }));
    }));

  describe('query', () =>
    it('should return the query', () => {
      const query = DatabaseStore.findAll(Thread);
      const subscription = new QuerySubscription(query);
      expect(subscription.query()).toBe(query);
    }));

  describe('addCallback', () =>
    it('should emit the last result to the new callback if one is available', () => {
      const cb = jasmine.createSpy('callback');
      spyOn(QuerySubscription.prototype, 'update').andReturn();
      const subscription = new QuerySubscription(DatabaseStore.findAll(Thread));
      subscription._lastResult = 'something';
      runs(() => {
        subscription.addCallback(cb);
        advanceClock();
      });
      waitsFor(() => cb.calls.length > 0);
      runs(() => expect(cb).toHaveBeenCalledWith('something'));
    }));

  describe('applyChangeRecord', () => {
    spyOn(Utils, 'generateTempId').andCallFake(() => undefined);

    const scenarios = [
      {
        name: 'query with full set of objects (4)',
        query: DatabaseStore.findAll(Thread)
          .where(Thread.attributes.accountId.equal('a'))
          .limit(4)
          .offset(2),
        lastModels: [
          new Thread({ accountId: 'a', id: '4', lastMessageReceivedTimestamp: 4 }),
          new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 3 }),
          new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 2 }),
          new Thread({ accountId: 'a', id: '1', lastMessageReceivedTimestamp: 1 }),
        ],
        tests: [
          {
            name: 'Item in set saved - new id, same sort value',
            change: {
              objectClass: Thread.name,
              objects: [
                new Thread({
                  accountId: 'a',
                  id: '4',
                  lastMessageReceivedTimestamp: 4,
                  subject: 'hello',
                }),
              ],
              type: 'persist',
            },
            nextModels: [
              new Thread({
                accountId: 'a',
                id: '4',
                lastMessageReceivedTimestamp: 4,
                subject: 'hello',
              }),
              new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 3 }),
              new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 2 }),
              new Thread({ accountId: 'a', id: '1', lastMessageReceivedTimestamp: 1 }),
            ],
            mustUpdate: false,
            mustTrigger: true,
          },
          {
            name: 'Item in set saved - new sort value',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'a', id: '5', lastMessageReceivedTimestamp: 3.5 })],
              type: 'persist',
            },
            nextModels: [
              new Thread({ accountId: 'a', id: '4', lastMessageReceivedTimestamp: 4 }),
              new Thread({ accountId: 'a', id: '5', lastMessageReceivedTimestamp: 3.5 }),
              new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 3 }),
              new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 2 }),
            ],
            mustUpdate: true,
            mustTrigger: true,
          },
          {
            name: 'Item saved - does not match query clauses, offset > 0',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'b', id: '5', lastMessageReceivedTimestamp: 5 })],
              type: 'persist',
            },
            nextModels: 'unchanged',
            mustUpdate: true,
          },
          {
            name: 'Item saved - matches query clauses',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'a', id: '5', lastMessageReceivedTimestamp: -2 })],
              type: 'persist',
            },
            mustUpdate: true,
          },
          {
            name: 'Item in set saved - no longer matches query clauses',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'b', id: '4', lastMessageReceivedTimestamp: 4 })],
              type: 'persist',
            },
            nextModels: [
              new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 3 }),
              new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 2 }),
              new Thread({ accountId: 'a', id: '1', lastMessageReceivedTimestamp: 1 }),
            ],
            mustUpdate: true,
          },
          {
            name: 'Item in set deleted',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'a', id: '4' })],
              type: 'unpersist',
            },
            nextModels: [
              new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 3 }),
              new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 2 }),
              new Thread({ accountId: 'a', id: '1', lastMessageReceivedTimestamp: 1 }),
            ],
            mustUpdate: true,
          },
          {
            name: 'Item not in set deleted',
            change: {
              objectClass: Thread.name,
              objects: [new Thread({ accountId: 'a', id: '5' })],
              type: 'unpersist',
            },
            nextModels: 'unchanged',
            mustUpdate: false,
          },
        ],
      },
      {
        name: 'query with multiple sort orders',
        query: DatabaseStore.findAll(Thread)
          .where(Thread.attributes.accountId.equal('a'))
          .limit(4)
          .offset(2)
          .order([
            Thread.attributes.lastMessageReceivedTimestamp.ascending(),
            Thread.attributes.unread.descending(),
          ]),
        lastModels: [
          new Thread({ accountId: 'a', id: '1', lastMessageReceivedTimestamp: 1, unread: true }),
          new Thread({ accountId: 'a', id: '2', lastMessageReceivedTimestamp: 1, unread: false }),
          new Thread({ accountId: 'a', id: '3', lastMessageReceivedTimestamp: 1, unread: false }),
          new Thread({ accountId: 'a', id: '4', lastMessageReceivedTimestamp: 2, unread: true }),
        ],
        tests: [
          {
            name: 'Item in set saved, secondary sort order changed',
            change: {
              objectClass: Thread.name,
              objects: [
                new Thread({
                  accountId: 'a',
                  id: '3',
                  lastMessageReceivedTimestamp: 1,
                  unread: true,
                }),
              ],
              type: 'persist',
            },
            mustUpdate: true,
          },
        ],
      },
    ];

    jasmine.unspy(Utils, 'generateTempId');

    describe('scenarios', () =>
      scenarios.forEach(scenario => {
        scenario.tests.forEach(test => {
          it(`with ${scenario.name}, should correctly apply ${test.name}`, () => {
            const subscription = new QuerySubscription(scenario.query);
            subscription._set = new MutableQueryResultSet();
            subscription._set.addModelsInRange(
              scenario.lastModels,
              new QueryRange({ start: 0, end: scenario.lastModels.length })
            );

            spyOn(subscription, 'update');
            spyOn(subscription, '_createResultAndTrigger');
            subscription._updateInFlight = false;
            subscription.applyChangeRecord(test.change);

            if (test.mustUpdate) {
              expect(subscription.update).toHaveBeenCalledWith({ mustRefetchEntireRange: true });
            } else if (test.nextModels === 'unchanged') {
              expect(subscription._set.models()).toEqual(scenario.lastModels);
            } else {
              expect(subscription._set.models()).toEqual(test.nextModels);
            }

            if (test.mustTriger) {
              expect(subscription._createResultAndTrigger).toHaveBeenCalled();
            }
          });
        });
      }));
  });

  describe('update', () => {
    beforeEach(() =>
      spyOn(QuerySubscription.prototype, '_fetchRange').andCallFake(() => {
        if (this._set == null) {
          this._set = new MutableQueryResultSet();
        }
        return Promise.resolve();
      })
    );

    describe('when the query has an infinite range', () => {
      it('should call _fetchRange for the entire range', () => {
        const subscription = new QuerySubscription(DatabaseStore.findAll(Thread));
        subscription.update();
        advanceClock();
        expect(subscription._fetchRange).toHaveBeenCalledWith(QueryRange.infinite(), {
          fetchEntireModels: true,
          version: 1,
        });
      });

      it('should fetch full full models only when the previous set is empty', () => {
        const subscription = new QuerySubscription(DatabaseStore.findAll(Thread));
        subscription._set = new MutableQueryResultSet();
        subscription._set.addModelsInRange([new Thread()], new QueryRange({ start: 0, end: 1 }));
        subscription.update();
        advanceClock();
        expect(subscription._fetchRange).toHaveBeenCalledWith(QueryRange.infinite(), {
          fetchEntireModels: false,
          version: 1,
        });
      });
    });

    describe('when the query has a range', () => {
      beforeEach(() => {
        this.query = DatabaseStore.findAll(Thread).limit(10);
      });

      describe('when we have no current range', () =>
        it('should call _fetchRange for the entire range and fetch full models', () => {
          const subscription = new QuerySubscription(this.query);
          subscription._set = null;
          subscription.update();
          advanceClock();
          expect(subscription._fetchRange).toHaveBeenCalledWith(this.query.range(), {
            fetchEntireModels: true,
            version: 1,
          });
        }));

      describe('when we have a previous range', () => {
        it('should call _fetchRange with the missingRange', () => {
          const customRange = jasmine.createSpy('customRange1');
          spyOn(QueryRange, 'rangesBySubtracting').andReturn([customRange]);
          const subscription = new QuerySubscription(this.query);
          subscription._set = new MutableQueryResultSet();
          subscription._set.addModelsInRange([new Thread()], new QueryRange({ start: 0, end: 1 }));

          advanceClock();
          subscription._fetchRange.reset();
          subscription._updateInFlight = false;
          subscription.update();
          advanceClock();
          expect(subscription._fetchRange.callCount).toBe(1);
          expect(subscription._fetchRange.calls[0].args).toEqual([
            customRange,
            { fetchEntireModels: true, version: 1 },
          ]);
        });

        it('should call _fetchRange for the entire query range when the missing range encompasses more than one range', () => {
          const customRange1 = jasmine.createSpy('customRange1');
          const customRange2 = jasmine.createSpy('customRange2');
          spyOn(QueryRange, 'rangesBySubtracting').andReturn([customRange1, customRange2]);

          const range = new QueryRange({ start: 0, end: 1 });
          const subscription = new QuerySubscription(this.query);
          subscription._set = new MutableQueryResultSet();
          subscription._set.addModelsInRange([new Thread()], range);

          advanceClock();
          subscription._fetchRange.reset();
          subscription._updateInFlight = false;
          subscription.update();
          advanceClock();
          expect(subscription._fetchRange.callCount).toBe(1);
          expect(subscription._fetchRange.calls[0].args).toEqual([
            this.query.range(),
            { fetchEntireModels: true, version: 1 },
          ]);
        });
      });
    });
  });
});
