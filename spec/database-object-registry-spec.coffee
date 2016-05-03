_ = require 'underscore'
Model = require '../src/flux/models/model'
Attributes = require '../src/flux/attributes'
DatabaseObjectRegistry = require('../src/database-object-registry').default

class GoodTest extends Model
  @attributes: _.extend {}, Model.attributes,
    "foo": Attributes.String
      modelKey: 'foo'
      jsonKey: 'foo'

describe 'DatabaseObjectRegistry', ->
  beforeEach ->
    DatabaseObjectRegistry.unregister("GoodTest")

  it "can register constructors", ->
    testFn = -> GoodTest
    expect( -> DatabaseObjectRegistry.register("GoodTest", testFn)).not.toThrow()
    expect(DatabaseObjectRegistry.get("GoodTest")).toBe GoodTest

  it "Tests if a constructor is in the registry", ->
    DatabaseObjectRegistry.register("GoodTest", -> GoodTest)
    expect(DatabaseObjectRegistry.isInRegistry("GoodTest")).toBe true

  it "deserializes the objects for a constructor", ->
    DatabaseObjectRegistry.register("GoodTest", -> GoodTest)
    obj = DatabaseObjectRegistry.deserialize("GoodTest", foo: "bar")
    expect(obj instanceof GoodTest).toBe true
    expect(obj.foo).toBe "bar"

  it "throws an error if the object can't be deserialized", ->
    expect( -> DatabaseObjectRegistry.deserialize("GoodTest", foo: "bar")).toThrow()
