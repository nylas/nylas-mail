Model = require '../../src/flux/models/model'
{isTempId} = require '../../src/flux/models/utils'

describe "Model", ->
  describe "constructor", ->
    it "should accept a hash of attributes and assign them to the new Model", ->
      attrs =
        id: "A",
        namespaceId: "B"
      m = new Model(attrs)
      expect(m.id).toBe(attrs.id)
      expect(m.namespaceId).toBe(attrs.namespaceId)

    it "should assign a local- ID to the model if no ID is provided", ->
      m = new Model
      expect(isTempId(m.id)).toBe(true)

  describe "attributes", ->
    it "should return the attributes of the class", ->
      m = new Model()
      expect(m.attributes()).toBe(m.constructor.attributes)

  describe "isEqual", ->
    it "should return true iff the classes and IDs match", ->
      class Submodel extends Model
        constructor: -> super

      a = new Model({id: "A"})
      b = new Model({id: "B"})
      aSub = new Submodel({id: "A"})
      aEqualSub = new Submodel({id: "A"})

      expect(a.isEqual(b)).toBe(false)
      expect(a.isEqual(aSub)).toBe(false)
      expect(aSub.isEqual(aEqualSub)).toBe(true)

  describe "isSaved", ->
    it "should return false if the object has a temp ID", ->
      a = new Model()
      expect(a.isSaved()).toBe(false)

      b = new Model({id: "b"})
      expect(b.isSaved()).toBe(true)

  describe "fromJSON", ->
    beforeEach ->
      @json =
        'id': '1234'
        'daysOld': 4
        'namespace_id': 'bla'
      @m = new Model

    it "should assign attribute values by calling through to attribute fromJSON functions", ->
      spyOn(Model.attributes.namespaceId, 'fromJSON').andCallFake (json) ->
        'inflated value!'
      @m.fromJSON(@json)
      expect(Model.attributes.namespaceId.fromJSON.callCount).toBe 1
      expect(@m.namespaceId).toBe('inflated value!')

    it "should not touch attributes that are missing in the json", ->
      @m.fromJSON(@json)
      expect(@m.object).toBe(undefined)

      @m.object = 'abc'
      @m.fromJSON(@json)
      expect(@m.object).toBe('abc')

    it "should not do anything with extra JSON keys", ->
      @m.fromJSON(@json)
      expect(@m.daysOld).toBe(undefined)

  describe "toJSON", ->
    beforeEach ->
      @model = new Model
        id: "1234",
        namespaceId: "ACD"

    it "should return a JSON object and call attribute toJSON functions to map values", ->
      spyOn(Model.attributes.namespaceId, 'toJSON').andCallFake (json) ->
        'inflated value!'

      json = @model.toJSON()
      expect(json instanceof Object).toBe(true)
      expect(json.id).toBe('1234')
      expect(json.namespace_id).toBe('inflated value!')

    it "should surface any exception one of the attribute toJSON functions raises", ->
      spyOn(Model.attributes.namespaceId, 'toJSON').andCallFake (json) ->
        throw "Can't convert value into JSON format"
      expect(-> @model.toJSON()).toThrow()

  describe "matches", ->
    beforeEach ->
      @model = new Model
        id: "1234",
        namespaceId: "ACD"

      @truthyMatcher =
        evaluate: (model) -> true
      @falsyMatcher =
        evaluate: (model) -> false

    it "should run the matchers and return true iff all matchers pass", ->
      expect(@model.matches([@truthyMatcher, @truthyMatcher])).toBe(true)
      expect(@model.matches([@truthyMatcher, @falsyMatcher])).toBe(false)
      expect(@model.matches([@falsyMatcher, @truthyMatcher])).toBe(false)

    it "should pass itself as an argument to the matchers", ->
      spyOn(@truthyMatcher, 'evaluate').andCallFake (param) =>
        expect(param).toBe(@model)
      @model.matches([@truthyMatcher])

