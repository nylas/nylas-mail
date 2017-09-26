/* eslint quote-props: 0 */
import Thread from '../../src/flux/models/thread';
import TestModel from '../fixtures/db-test-model';
import ModelQuery from '../../src/flux/models/query';
import DatabaseStore from '../../src/flux/stores/database-store';

const testMatchers = { id: 'b' };

describe('DatabaseStore', function DatabaseStoreSpecs() {
  beforeEach(() => {
    TestModel.configureBasic();
    spyOn(ModelQuery.prototype, 'where').andCallThrough();

    this.performed = [];

    // Note: We spy on _query and test all of the convenience methods that sit above
    // it. None of these tests evaluate whether _query works!
    jasmine.unspy(DatabaseStore, '_query');
    spyOn(DatabaseStore, '_query').andCallFake((query, values = []) => {
      this.performed.push({ query, values });
      return Promise.resolve([]);
    });
  });

  describe('find', () =>
    it('should return a ModelQuery for retrieving a single item by Id', () => {
      const q = DatabaseStore.find(TestModel, '4');
      expect(q.sql()).toBe(
        "SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = '4'  LIMIT 1"
      );
    }));

  describe('findBy', () => {
    it('should pass the provided predicates on to the ModelQuery', () => {
      DatabaseStore.findBy(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it('should return a ModelQuery ready to be executed', () => {
      const q = DatabaseStore.findBy(TestModel, testMatchers);
      expect(q.sql()).toBe(
        "SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  LIMIT 1"
      );
    });
  });

  describe('findAll', () => {
    it('should pass the provided predicates on to the ModelQuery', () => {
      DatabaseStore.findAll(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it('should return a ModelQuery ready to be executed', () => {
      const q = DatabaseStore.findAll(TestModel, testMatchers);
      expect(q.sql()).toBe(
        "SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  "
      );
    });
  });

  describe('modelify', () => {
    beforeEach(() => {
      this.models = [
        new Thread({ id: 'local-A' }),
        new Thread({ id: 'local-B' }),
        new Thread({ id: 'local-C' }),
        new Thread({ id: 'local-D' }),
        new Thread({ id: 'local-E' }),
        new Thread({ id: 'local-F' }),
        new Thread({ id: 'local-G' }),
      ];
      // Actually returns correct sets for queries, since matchers can evaluate
      // themselves against models in memory
      spyOn(DatabaseStore, 'run').andCallFake(query => {
        const results = this.models.filter(model =>
          query._matchers.every(matcher => matcher.evaluate(model))
        );
        return Promise.resolve(results);
      });
    });

    describe('when given an array or input that is not an array', () =>
      it('resolves immediately with an empty array', () =>
        waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, null).then(output => {
            expect(output).toEqual([]);
          });
        })));

    describe('when given an array of mixed IDs, and models', () =>
      it('resolves with an array of models', () => {
        const input = ['local-F', 'local-B', 'local-C', 'local-D', this.models[6]];
        const expectedOutput = [
          this.models[5],
          this.models[1],
          this.models[2],
          this.models[3],
          this.models[6],
        ];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      }));

    describe('when the input is only IDs', () =>
      it('resolves with an array of models', () => {
        const input = ['local-D', 'local-F', 'local-G'];
        const expectedOutput = [this.models[3], this.models[5], this.models[6]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      }));

    describe('when the input is all models', () =>
      it('resolves with an array of models', () => {
        const input = [this.models[0], this.models[1], this.models[2], this.models[3]];
        const expectedOutput = [this.models[0], this.models[1], this.models[2], this.models[3]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      }));
  });

  describe('count', () => {
    it('should pass the provided predicates on to the ModelQuery', () => {
      DatabaseStore.findAll(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it('should return a ModelQuery configured for COUNT ready to be executed', () => {
      const q = DatabaseStore.findAll(TestModel, testMatchers);
      expect(q.sql()).toBe(
        "SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  "
      );
    });
  });
});
