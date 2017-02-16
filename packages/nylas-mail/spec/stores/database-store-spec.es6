/* eslint quote-props: 0 */
import Thread from '../../src/flux/models/thread';
import TestModel from '../fixtures/db-test-model';
import ModelQuery from '../../src/flux/models/query';
import DatabaseStore from '../../src/flux/stores/database-store';

const testMatchers = {'id': 'b'};

describe("DatabaseStore", function DatabaseStoreSpecs() {
  beforeEach(() => {
    TestModel.configureBasic();

    DatabaseStore._atomicallyQueue = undefined;
    DatabaseStore._mutationQueue = undefined;
    DatabaseStore._inTransaction = false;

    spyOn(ModelQuery.prototype, 'where').andCallThrough();
    spyOn(DatabaseStore, 'accumulateAndTrigger').andCallFake(() => Promise.resolve());

    this.performed = [];

    // Note: We spy on _query and test all of the convenience methods that sit above
    // it. None of these tests evaluate whether _query works!
    jasmine.unspy(DatabaseStore, "_query");
    spyOn(DatabaseStore, "_query").andCallFake((query, values = []) => {
      this.performed.push({query, values});
      return Promise.resolve([]);
    });
  });

  describe("find", () =>
    it("should return a ModelQuery for retrieving a single item by Id", () => {
      const q = DatabaseStore.find(TestModel, "4");
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = '4'  LIMIT 1");
    })

  );

  describe("findBy", () => {
    it("should pass the provided predicates on to the ModelQuery", () => {
      DatabaseStore.findBy(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it("should return a ModelQuery ready to be executed", () => {
      const q = DatabaseStore.findBy(TestModel, testMatchers);
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  LIMIT 1");
    });
  });

  describe("findAll", () => {
    it("should pass the provided predicates on to the ModelQuery", () => {
      DatabaseStore.findAll(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it("should return a ModelQuery ready to be executed", () => {
      const q = DatabaseStore.findAll(TestModel, testMatchers);
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  ");
    });
  });

  describe("modelify", () => {
    beforeEach(() => {
      this.models = [
        new Thread({clientId: 'local-A'}),
        new Thread({clientId: 'local-B'}),
        new Thread({clientId: 'local-C'}),
        new Thread({clientId: 'local-D', serverId: 'SERVER:D'}),
        new Thread({clientId: 'local-E', serverId: 'SERVER:E'}),
        new Thread({clientId: 'local-F', serverId: 'SERVER:F'}),
        new Thread({clientId: 'local-G', serverId: 'SERVER:G'}),
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

    describe("when given an array or input that is not an array", () =>
      it("resolves immediately with an empty array", () =>
        waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, null).then(output => {
            expect(output).toEqual([]);
          });
        })
      )
    );

    describe("when given an array of mixed IDs, clientIDs, and models", () =>
      it("resolves with an array of models", () => {
        const input = ['SERVER:F', 'local-B', 'local-C', 'SERVER:D', this.models[6]];
        const expectedOutput = [this.models[5], this.models[1], this.models[2], this.models[3], this.models[6]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      })

    );

    describe("when the input is only IDs", () =>
      it("resolves with an array of models", () => {
        const input = ['SERVER:D', 'SERVER:F', 'SERVER:G'];
        const expectedOutput = [this.models[3], this.models[5], this.models[6]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      })

    );

    describe("when the input is only clientIDs", () =>
      it("resolves with an array of models", () => {
        const input = ['local-A', 'local-B', 'local-C', 'local-D'];
        const expectedOutput = [this.models[0], this.models[1], this.models[2], this.models[3]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      })

    );

    describe("when the input is all models", () =>
      it("resolves with an array of models", () => {
        const input = [this.models[0], this.models[1], this.models[2], this.models[3]];
        const expectedOutput = [this.models[0], this.models[1], this.models[2], this.models[3]];
        return waitsForPromise(() => {
          return DatabaseStore.modelify(Thread, input).then(output => {
            expect(output).toEqual(expectedOutput);
          });
        });
      })

    );
  });

  describe("count", () => {
    it("should pass the provided predicates on to the ModelQuery", () => {
      DatabaseStore.findAll(TestModel, testMatchers);
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers);
    });

    it("should return a ModelQuery configured for COUNT ready to be executed", () => {
      const q = DatabaseStore.findAll(TestModel, testMatchers);
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  ");
    });
  });

  describe("inTransaction", () => {
    it("calls the provided function inside an exclusive transaction", () =>
      waitsForPromise(() => {
        return DatabaseStore.inTransaction(() => {
          return DatabaseStore._query("TEST");
        }).then(() => {
          expect(this.performed.length).toBe(3);
          expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[1].query).toBe("TEST");
          expect(this.performed[2].query).toBe("COMMIT");
        });
      })

    );

    it("preserves resolved values", () =>
      waitsForPromise(() => {
        return DatabaseStore.inTransaction(() => {
          DatabaseStore._query("TEST");
          return Promise.resolve("myValue");
        }).then(myValue => {
          expect(myValue).toBe("myValue");
        });
      })

    );

    it("always fires a COMMIT, even if the body function fails", () =>
      waitsForPromise(() => {
        return DatabaseStore.inTransaction(() => {
          throw new Error("BOOO");
        }).catch(() => {
          expect(this.performed.length).toBe(2);
          expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[1].query).toBe("COMMIT");
        });
      })

    );

    it("can be called multiple times and get queued", () =>
      waitsForPromise(() => {
        return Promise.all([
          DatabaseStore.inTransaction(() => Promise.resolve()),
          DatabaseStore.inTransaction(() => Promise.resolve()),
          DatabaseStore.inTransaction(() => Promise.resolve()),
        ]).then(() => {
          expect(this.performed.length).toBe(6);
          expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[1].query).toBe("COMMIT");
          expect(this.performed[2].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[3].query).toBe("COMMIT");
          expect(this.performed[4].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[5].query).toBe("COMMIT");
        });
      })

    );

    it("carries on if one of them fails, but still calls the COMMIT for the failed block", async () => {
      let caughtError = false;
      const p1 = DatabaseStore.inTransaction(() => DatabaseStore._query("ONE"));
      const p2 = DatabaseStore.inTransaction(() => { throw new Error("fail"); }).catch(() => { caughtError = true });
      const p3 = DatabaseStore.inTransaction(() => DatabaseStore._query("THREE"));
      await Promise.all([p1, p2, p3])
      expect(this.performed.length).toBe(8);
      expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
      expect(this.performed[1].query).toBe("ONE");
      expect(this.performed[2].query).toBe("COMMIT");
      expect(this.performed[3].query).toBe("BEGIN IMMEDIATE TRANSACTION");
      expect(this.performed[4].query).toBe("COMMIT");
      expect(this.performed[5].query).toBe("BEGIN IMMEDIATE TRANSACTION");
      expect(this.performed[6].query).toBe("THREE");
      expect(this.performed[7].query).toBe("COMMIT");
      expect(caughtError).toBe(true);
    });

    it("is actually running in series and blocks on never-finishing specs", async () => {
      let resolver = null;
      await DatabaseStore.inTransaction(() => Promise.resolve());
      expect(this.performed.length).toBe(2);
      expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
      expect(this.performed[1].query).toBe("COMMIT");
      DatabaseStore.inTransaction(() => new Promise((resolve) => { resolver = resolve }));
      let blockedPromiseDone = false;
      DatabaseStore.inTransaction(() => Promise.resolve()).then(() => {
        blockedPromiseDone = true;
      });
      await new Promise(setImmediate)
      expect(this.performed.length).toBe(3);
      expect(this.performed[2].query).toBe("BEGIN IMMEDIATE TRANSACTION");
      expect(blockedPromiseDone).toBe(false);
      resolver();
      await new Promise(setImmediate)
      expect(blockedPromiseDone).toBe(true);
    });

    it("can be called multiple times and preserve return values", () =>
      waitsForPromise(() => {
        let v1 = null;
        let v2 = null;
        let v3 = null;
        return Promise.all([
          DatabaseStore.inTransaction(() => Promise.resolve("a")).then(val => { v1 = val }),
          DatabaseStore.inTransaction(() => Promise.resolve("b")).then(val => { v2 = val }),
          DatabaseStore.inTransaction(() => Promise.resolve("c")).then(val => { v3 = val }),
        ]).then(() => {
          expect(v1).toBe("a");
          expect(v2).toBe("b");
          expect(v3).toBe("c");
        });
      })

    );

    it("can be called multiple times and get queued", () =>
      waitsForPromise(() => {
        return DatabaseStore.inTransaction(() => Promise.resolve())
        .then(() => DatabaseStore.inTransaction(() => Promise.resolve()))
        .then(() => DatabaseStore.inTransaction(() => Promise.resolve()))
        .then(() => {
          expect(this.performed.length).toBe(6);
          expect(this.performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[1].query).toBe("COMMIT");
          expect(this.performed[2].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[3].query).toBe("COMMIT");
          expect(this.performed[4].query).toBe("BEGIN IMMEDIATE TRANSACTION");
          expect(this.performed[5].query).toBe("COMMIT");
        });
      })

    );
  });
});
