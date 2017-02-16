/* eslint dot-notation:0 */
import Category from '../../src/flux/models/category';
import TestModel from '../fixtures/db-test-model';
import DatabaseTransaction from '../../src/flux/stores/database-transaction';

const testModelInstance = new TestModel({id: "1234"});
const testModelInstanceA = new TestModel({id: "AAA"});
const testModelInstanceB = new TestModel({id: "BBB"});

function __range__(left, right, inclusive) {
  const range = [];
  const ascending = left < right;
  const incr = ascending ? right + 1 : right - 1;
  const end = !inclusive ? right : incr;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}

xdescribe("DatabaseTransaction", function DatabaseTransactionSpecs() {
  beforeEach(() => {
    this.databaseMutationHooks = [];
    this.performed = [];
    this.database = {
      _query: jasmine.createSpy('database._query').andCallFake((query, values = []) => {
        this.performed.push({query, values});
        return Promise.resolve([]);
      }),
      accumulateAndTrigger: jasmine.createSpy('database.accumulateAndTrigger'),
      mutationHooks: () => this.databaseMutationHooks,
    };

    this.transaction = new DatabaseTransaction(this.database);
  });

  describe("execute", () => {});

  describe("persistModel", () => {
    it("should throw an exception if the model is not a subclass of Model", () => expect(() => this.transaction.persistModel({id: 'asd', subject: 'bla'})).toThrow()
    );

    it("should call through to persistModels", () => {
      spyOn(this.transaction, 'persistModels').andReturn(Promise.resolve());
      this.transaction.persistModel(testModelInstance);
      advanceClock();
      expect(this.transaction.persistModels.callCount).toBe(1);
    });
  });

  describe("persistModels", () => {
    it("should call accumulateAndTrigger with a change that contains the models", () => {
      runs(() => {
        return this.transaction.execute(t => {
          return t.persistModels([testModelInstanceA, testModelInstanceB]);
        });
      });
      waitsFor(() => {
        return this.database.accumulateAndTrigger.callCount > 0;
      });
      runs(() => {
        const change = this.database.accumulateAndTrigger.mostRecentCall.args[0];
        expect(change).toEqual({
          objectClass: TestModel.name,
          objectIds: [testModelInstanceA.id, testModelInstanceB.id],
          objects: [testModelInstanceA, testModelInstanceB],
          type: 'persist',
        });
      });
    });

    it("should call through to _writeModels after checking them", () => {
      spyOn(this.transaction, '_writeModels').andReturn(Promise.resolve());
      this.transaction.persistModels([testModelInstanceA, testModelInstanceB]);
      advanceClock();
      expect(this.transaction._writeModels.callCount).toBe(1);
    });

    it("should throw an exception if the models are not the same class, since it cannot be specified by the trigger payload", () =>
      expect(() => this.transaction.persistModels([testModelInstanceA, new Category()])).toThrow()
    );

    it("should throw an exception if the models are not a subclass of Model", () =>
      expect(() => this.transaction.persistModels([{id: 'asd', subject: 'bla'}])).toThrow()
    );

    describe("mutationHooks", () => {
      beforeEach(() => {
        this.beforeShouldThrow = false;
        this.beforeShouldReject = false;

        this.hook = {
          beforeDatabaseChange: jasmine.createSpy('beforeDatabaseChange').andCallFake(() => {
            if (this.beforeShouldThrow) { throw new Error("beforeShouldThrow"); }
            return new Promise((resolve) => {
              setTimeout(() => {
                if (this.beforeShouldReject) { resolve(new Error("beforeShouldReject")); }
                resolve("value");
              }
              , 1000);
            });
          }),
          afterDatabaseChange: jasmine.createSpy('afterDatabaseChange').andCallFake(() => {
            return new Promise((resolve) => setTimeout(() => resolve(), 1000));
          }),
        };

        this.databaseMutationHooks.push(this.hook);

        this.writeModelsResolve = null;
        spyOn(this.transaction, '_writeModels').andCallFake(() => {
          return new Promise((resolve) => {
            this.writeModelsResolve = resolve;
          });
        });
      });

      it("should run pre-mutation hooks, wait to write models, and then run post-mutation hooks", () => {
        this.transaction.persistModels([testModelInstanceA, testModelInstanceB]);
        advanceClock();
        expect(this.hook.beforeDatabaseChange).toHaveBeenCalledWith(
          this.transaction._query,
          {
            objects: [testModelInstanceA, testModelInstanceB],
            objectIds: [testModelInstanceA.id, testModelInstanceB.id],
            objectClass: testModelInstanceA.constructor.name,
            type: 'persist',
          },
          undefined
        );
        expect(this.transaction._writeModels).not.toHaveBeenCalled();
        advanceClock(1100);
        advanceClock();
        expect(this.transaction._writeModels).toHaveBeenCalled();
        expect(this.hook.afterDatabaseChange).not.toHaveBeenCalled();
        this.writeModelsResolve();
        advanceClock();
        advanceClock();
        expect(this.hook.afterDatabaseChange).toHaveBeenCalledWith(
          this.transaction._query,
          {
            objects: [testModelInstanceA, testModelInstanceB],
            objectIds: [testModelInstanceA.id, testModelInstanceB.id],
            objectClass: testModelInstanceA.constructor.name,
            type: 'persist',
          },
          "value"
        );
      });

      it("should carry on if a pre-mutation hook throws", () => {
        this.beforeShouldThrow = true;
        this.transaction.persistModels([testModelInstanceA, testModelInstanceB]);
        advanceClock(1000);
        expect(this.hook.beforeDatabaseChange).toHaveBeenCalled();
        advanceClock();
        advanceClock();
        expect(this.transaction._writeModels).toHaveBeenCalled();
      });

      it("should carry on if a pre-mutation hook rejects", () => {
        this.beforeShouldReject = true;
        this.transaction.persistModels([testModelInstanceA, testModelInstanceB]);
        advanceClock(1000);
        expect(this.hook.beforeDatabaseChange).toHaveBeenCalled();
        advanceClock();
        advanceClock();
        expect(this.transaction._writeModels).toHaveBeenCalled();
      });
    });
  });

  describe("unpersistModel", () => {
    it("should delete the model by id", () =>
      waitsForPromise(() => {
        return this.transaction.execute(() => {
          return this.transaction.unpersistModel(testModelInstance);
        })
        .then(() => {
          expect(this.performed.length).toBe(3);
          expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[1].query).toBe("DELETE FROM `TestModel` WHERE `id` = ?");
          expect(this.performed[1].values[0]).toBe('1234');
          expect(this.performed[2].query).toBe("COMMIT");
        });
      })

    );

    it("should call accumulateAndTrigger with a change that contains the model", () => {
      runs(() => {
        return this.transaction.execute(() => {
          return this.transaction.unpersistModel(testModelInstance);
        });
      });
      waitsFor(() => {
        return this.database.accumulateAndTrigger.callCount > 0;
      });
      runs(() => {
        const change = this.database.accumulateAndTrigger.mostRecentCall.args[0];
        expect(change).toEqual({
          objectClass: TestModel.name,
          objectIds: [testModelInstance.id],
          objects: [testModelInstance],
          type: 'unpersist',
        });
      });
    });

    describe("when the model has collection attributes", () =>
      it("should delete all of the elements in the join tables", () => {
        TestModel.configureWithCollectionAttribute();
        waitsForPromise(() => {
          return this.transaction.execute(t => {
            return t.unpersistModel(testModelInstance);
          })
          .then(() => {
            expect(this.performed.length).toBe(4);
            expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
            expect(this.performed[2].query).toBe("DELETE FROM `TestModelCategory` WHERE `id` = ?");
            expect(this.performed[2].values[0]).toBe('1234');
            expect(this.performed[3].query).toBe("COMMIT");
          });
        });
      })

    );

    describe("when the model has joined data attributes", () =>
      it("should delete the element in the joined data table", () => {
        TestModel.configureWithJoinedDataAttribute();
        waitsForPromise(() => {
          return this.transaction.execute(t => {
            return t.unpersistModel(testModelInstance);
          })
          .then(() => {
            expect(this.performed.length).toBe(4);
            expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
            expect(this.performed[2].query).toBe("DELETE FROM `TestModelBody` WHERE `id` = ?");
            expect(this.performed[2].values[0]).toBe('1234');
            expect(this.performed[3].query).toBe("COMMIT");
          });
        });
      })

    );
  });

  describe("_writeModels", () => {
    it("should compose a REPLACE INTO query to save the model", () => {
      TestModel.configureWithCollectionAttribute();
      this.transaction._writeModels([testModelInstance]);
      expect(this.performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,client_id,server_id,other) VALUES (?,?,?,?,?)");
    });

    it("should save the model JSON into the data column", () => {
      this.transaction._writeModels([testModelInstance]);
      expect(this.performed[0].values[1]).toEqual(JSON.stringify(testModelInstance));
    });

    describe("when the model defines additional queryable attributes", () => {
      beforeEach(() => {
        TestModel.configureWithAllAttributes();
        this.m = new TestModel({
          'id': 'local-6806434c-b0cd',
          'datetime': new Date(),
          'string': 'hello world',
          'boolean': true,
          'number': 15,
        });
      });

      it("should populate additional columns defined by the attributes", () => {
        this.transaction._writeModels([this.m]);
        expect(this.performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,datetime,string-json-key,boolean,number) VALUES (?,?,?,?,?,?)");
      });

      it("should use the JSON-form values of the queryable attributes", () => {
        const json = this.m.toJSON();
        this.transaction._writeModels([this.m]);

        const { values } = this.performed[0];
        expect(values[2]).toEqual(json['datetime']);
        expect(values[3]).toEqual(json['string-json-key']);
        expect(values[4]).toEqual(json['boolean']);
        expect(values[5]).toEqual(json['number']);
      });
    });

    describe("when the model has collection attributes", () => {
      beforeEach(() => {
        TestModel.configureWithCollectionAttribute();
        this.m = new TestModel({id: 'local-6806434c-b0cd', other: 'other'});
        this.m.categories = [new Category({id: 'a'}), new Category({id: 'b'})];
        this.transaction._writeModels([this.m]);
      });

      it("should delete all association records for the model from join tables", () => {
        expect(this.performed[1].query).toBe('DELETE FROM `TestModelCategory` WHERE `id` IN (\'local-6806434c-b0cd\')');
      });

      it("should insert new association records into join tables in a single query, and include queryableBy columns", () => {
        expect(this.performed[2].query).toBe('INSERT OR IGNORE INTO `TestModelCategory` (`id`,`value`,`other`) VALUES (?,?,?),(?,?,?)');
        expect(this.performed[2].values).toEqual(['local-6806434c-b0cd', 'a', 'other', 'local-6806434c-b0cd', 'b', 'other']);
      });
    });

    describe("model collection attributes query building", () => {
      beforeEach(() => {
        TestModel.configureWithCollectionAttribute();
        this.m = new TestModel({id: 'local-6806434c-b0cd', other: 'other'});
        this.m.categories = [];
      });

      it("should page association records into multiple queries correctly", () => {
        const iterable = __range__(0, 199, true);
        for (let j = 0; j < iterable.length; j++) {
          const i = iterable[j];
          this.m.categories.push(new Category({id: `id-${i}`}));
        }
        this.transaction._writeModels([this.m]);

        const collectionAttributeQueries = this.performed.filter(i => i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') === 0
        );

        expect(collectionAttributeQueries.length).toBe(1);
        expect(collectionAttributeQueries[0].values[(200 * 3) - 2]).toEqual('id-199');
      });

      it("should page association records into multiple queries correctly", () => {
        const iterable = __range__(0, 200, true);
        for (let j = 0; j < iterable.length; j++) {
          const i = iterable[j];
          this.m.categories.push(new Category({id: `id-${i}`}));
        }
        this.transaction._writeModels([this.m]);

        const collectionAttributeQueries = this.performed.filter(i => i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') === 0
        );

        expect(collectionAttributeQueries.length).toBe(2);
        expect(collectionAttributeQueries[0].values[(200 * 3) - 2]).toEqual('id-199');
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200');
      });

      it("should page association records into multiple queries correctly", () => {
        const iterable = __range__(0, 201, true);
        for (let j = 0; j < iterable.length; j++) {
          const i = iterable[j];
          this.m.categories.push(new Category({id: `id-${i}`}));
        }
        this.transaction._writeModels([this.m]);

        const collectionAttributeQueries = this.performed.filter(i => i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') === 0
        );

        expect(collectionAttributeQueries.length).toBe(2);
        expect(collectionAttributeQueries[0].values[(200 * 3) - 2]).toEqual('id-199');
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200');
        expect(collectionAttributeQueries[1].values[4]).toEqual('id-201');
      });
    });

    describe("when the model has joined data attributes", () => {
      beforeEach(() => TestModel.configureWithJoinedDataAttribute());

      it("should not include the value to the joined attribute in the JSON written to the main model table", () => {
        this.m = new TestModel({clientId: 'local-6806434c-b0cd', serverId: 'server-1', body: 'hello world'});
        this.transaction._writeModels([this.m]);
        expect(this.performed[0].values).toEqual(['server-1', '{"client_id":"local-6806434c-b0cd","server_id":"server-1","id":"server-1"}', 'local-6806434c-b0cd', 'server-1']);
      });

      it("should write the value to the joined table if it is defined", () => {
        this.m = new TestModel({id: 'local-6806434c-b0cd', body: 'hello world'});
        this.transaction._writeModels([this.m]);
        expect(this.performed[1].query).toBe('REPLACE INTO `TestModelBody` (`id`, `value`) VALUES (?, ?)');
        expect(this.performed[1].values).toEqual([this.m.id, this.m.body]);
      });

      it("should not write the value to the joined table if it undefined", () => {
        this.m = new TestModel({id: 'local-6806434c-b0cd'});
        this.transaction._writeModels([this.m]);
        expect(this.performed.length).toBe(1);
      });
    });
  });
});
