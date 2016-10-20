/* eslint quote-props: 0 */
import _ from 'underscore';

import Model from '../../src/flux/models/model';
import Utils from '../../src/flux/models/utils';
import Attributes from '../../src/flux/attributes';

describe("Model", function modelSpecs() {
  describe("constructor", () => {
    it("should accept a hash of attributes and assign them to the new Model", () => {
      const attrs = {
        id: "A",
        accountId: "B",
      };
      const m = new Model(attrs);
      expect(m.id).toBe(attrs.id);
      return expect(m.accountId).toBe(attrs.accountId);
    });

    it("by default assigns things passed into the id constructor to the serverId", () => {
      const attrs = {id: "A"};
      const m = new Model(attrs);
      return expect(m.serverId).toBe(attrs.id);
    });

    it("by default assigns values passed into the id constructor that look like localIds to be a localID", () => {
      const attrs = {id: "A"};
      const m = new Model(attrs);
      return expect(m.serverId).toBe(attrs.id);
    });

    it("assigns serverIds and clientIds", () => {
      const attrs = {
        clientId: "local-A",
        serverId: "A",
      };
      const m = new Model(attrs);
      expect(m.serverId).toBe(attrs.serverId);
      expect(m.clientId).toBe(attrs.clientId);
      return expect(m.id).toBe(attrs.serverId);
    });

    it("throws an error if you attempt to manually assign the id", () => {
      const m = new Model({id: "foo"});
      return expect(() => { m.id = "bar" }).toThrow();
    });

    return it("automatically assigns a clientId (and id) to the model if no id is provided", () => {
      const m = new Model();
      expect(Utils.isTempId(m.id)).toBe(true);
      expect(Utils.isTempId(m.clientId)).toBe(true);
      return expect(m.serverId).toBeUndefined();
    });
  });

  describe("attributes", () =>
    it("should return the attributes of the class EXCEPT the id field", () => {
      const m = new Model();
      const retAttrs = _.clone(m.constructor.attributes);
      delete retAttrs.id;
      return expect(m.attributes()).toEqual(retAttrs);
    })

  );

  describe("clone", () =>
    it("should return a deep copy of the object", () => {
      class SubSubmodel extends Model {
        static attributes = Object.assign({}, Model.attributes, {
          'value': Attributes.Number({
            modelKey: 'value',
            jsonKey: 'value',
          }),
        });
      }

      class Submodel extends Model {
        static attributes = Object.assign({}, Model.attributes, {
          'testNumber': Attributes.Number({
            modelKey: 'testNumber',
            jsonKey: 'test_number',
          }),
          'testArray': Attributes.Collection({
            itemClass: SubSubmodel,
            modelKey: 'testArray',
            jsonKey: 'test_array',
          }),
        });
      }

      const old = new Submodel({testNumber: 4, testArray: [new SubSubmodel({value: 2}), new SubSubmodel({value: 6})]});
      const clone = old.clone();

      // Check entire trees are equivalent
      expect(old.toJSON()).toEqual(clone.toJSON());
      // Check object identity has changed
      expect(old.constructor.name).toEqual(clone.constructor.name);
      expect(old.testArray).not.toBe(clone.testArray);
      // Check classes
      expect(old.testArray[0]).not.toBe(clone.testArray[0]);
      return expect(old.testArray[0].constructor.name).toEqual(clone.testArray[0].constructor.name);
    })

  );

  describe("fromJSON", () => {
    beforeEach(() => {
      class SubmodelItem extends Model {}

      class Submodel extends Model {
        static attributes = Object.assign({}, Model.attributes, {
          'testNumber': Attributes.Number({
            modelKey: 'testNumber',
            jsonKey: 'test_number',
          }),
          'testBoolean': Attributes.Boolean({
            modelKey: 'testBoolean',
            jsonKey: 'test_boolean',
          }),
          'testCollection': Attributes.Collection({
            modelKey: 'testCollection',
            jsonKey: 'test_collection',
            itemClass: SubmodelItem,
          }),
          'testJoinedData': Attributes.JoinedData({
            modelKey: 'testJoinedData',
            jsonKey: 'test_joined_data',
          }),
        });
      }

      this.json = {
        'id': '1234',
        'test_number': 4,
        'test_boolean': true,
        'daysOld': 4,
        'account_id': 'bla',
      };
      this.m = new Submodel();
    });

    it("should assign attribute values by calling through to attribute fromJSON functions", () => {
      spyOn(Model.attributes.accountId, 'fromJSON').andCallFake(() => 'inflated value!');
      this.m.fromJSON(this.json);
      expect(Model.attributes.accountId.fromJSON.callCount).toBe(1);
      return expect(this.m.accountId).toBe('inflated value!');
    });

    it("should not touch attributes that are missing in the json", () => {
      this.m.fromJSON(this.json);
      expect(this.m.object).toBe(undefined);

      this.m.object = 'abc';
      this.m.fromJSON(this.json);
      return expect(this.m.object).toBe('abc');
    });

    it("should not do anything with extra JSON keys", () => {
      this.m.fromJSON(this.json);
      return expect(this.m.daysOld).toBe(undefined);
    });

    it("should maintain empty string as empty strings", () => {
      expect(this.m.accountId).toBe(undefined);
      this.m.fromJSON({account_id: ''});
      return expect(this.m.accountId).toBe('');
    });

    describe("Attributes.Number", () =>
      it("should read number attributes and coerce them to numeric values", () => {
        this.m.fromJSON({'test_number': 4});
        expect(this.m.testNumber).toBe(4);

        this.m.fromJSON({'test_number': '4'});
        expect(this.m.testNumber).toBe(4);

        this.m.fromJSON({'test_number': 'lolz'});
        expect(this.m.testNumber).toBe(null);

        this.m.fromJSON({'test_number': 0});
        return expect(this.m.testNumber).toBe(0);
      })

    );

    describe("Attributes.JoinedData", () =>
      it("should read joined data attributes and coerce them to string values", () => {
        this.m.fromJSON({'test_joined_data': null});
        expect(this.m.testJoinedData).toBe(null);

        this.m.fromJSON({'test_joined_data': ''});
        expect(this.m.testJoinedData).toBe('');

        this.m.fromJSON({'test_joined_data': 'lolz'});
        return expect(this.m.testJoinedData).toBe('lolz');
      })

    );

    describe("Attributes.Collection", () => {
      it("should parse and inflate items", () => {
        this.m.fromJSON({'test_collection': [{id: '123'}]});
        expect(this.m.testCollection.length).toBe(1);
        expect(this.m.testCollection[0].id).toBe('123');
        return expect(this.m.testCollection[0].constructor.name).toBe('SubmodelItem');
      });

      return it("should be fine with malformed arrays", () => {
        this.m.fromJSON({'test_collection': [null]});
        expect(this.m.testCollection.length).toBe(0);
        this.m.fromJSON({'test_collection': []});
        expect(this.m.testCollection.length).toBe(0);
        this.m.fromJSON({'test_collection': null});
        return expect(this.m.testCollection.length).toBe(0);
      });
    });

    return describe("Attributes.Boolean", () =>
      it("should read `true` or true and coerce everything else to false", () => {
        this.m.fromJSON({'test_boolean': true});
        expect(this.m.testBoolean).toBe(true);

        this.m.fromJSON({'test_boolean': 'true'});
        expect(this.m.testBoolean).toBe(true);

        this.m.fromJSON({'test_boolean': 4});
        expect(this.m.testBoolean).toBe(false);

        this.m.fromJSON({'test_boolean': '4'});
        expect(this.m.testBoolean).toBe(false);

        this.m.fromJSON({'test_boolean': false});
        expect(this.m.testBoolean).toBe(false);

        this.m.fromJSON({'test_boolean': 0});
        expect(this.m.testBoolean).toBe(false);

        this.m.fromJSON({'test_boolean': null});
        return expect(this.m.testBoolean).toBe(false);
      })

    );
  });

  describe("toJSON", () => {
    beforeEach(() => {
      this.model = new Model({
        id: "1234",
        accountId: "ACD",
      });
      return;
    });

    it("should return a JSON object and call attribute toJSON functions to map values", () => {
      spyOn(Model.attributes.accountId, 'toJSON').andCallFake(() => 'inflated value!');

      const json = this.model.toJSON();
      expect(json instanceof Object).toBe(true);
      expect(json.id).toBe('1234');
      return expect(json.account_id).toBe('inflated value!');
    });

    return it("should surface any exception one of the attribute toJSON functions raises", () => {
      spyOn(Model.attributes.accountId, 'toJSON').andCallFake(() => {
        throw new Error("Can't convert value into JSON format");
      });
      return expect(() => { return this.model.toJSON(); }).toThrow();
    });
  });

  return describe("matches", () => {
    beforeEach(() => {
      this.model = new Model({
        id: "1234",
        accountId: "ACD",
      });

      this.truthyMatcher = {evaluate() { return true; }};
      this.falsyMatcher = {evaluate() { return false; }};
    });

    it("should run the matchers and return true iff all matchers pass", () => {
      expect(this.model.matches([this.truthyMatcher, this.truthyMatcher])).toBe(true);
      expect(this.model.matches([this.truthyMatcher, this.falsyMatcher])).toBe(false);
      return expect(this.model.matches([this.falsyMatcher, this.truthyMatcher])).toBe(false);
    });

    return it("should pass itself as an argument to the matchers", () => {
      spyOn(this.truthyMatcher, 'evaluate').andCallFake(param => {
        return expect(param).toBe(this.model);
      });
      return this.model.matches([this.truthyMatcher]);
    });
  });
});
