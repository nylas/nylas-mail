_ = require 'underscore'
Model = require '../src/flux/models/model'
Attributes = require '../src/flux/attributes'
DatabaseObjectRegistry = require '../src/database-object-registry'

class BadTest

class GoodTest extends Model
  @attributes: _.extend {}, Model.attributes,
    "foo": Attributes.String
      modelKey: 'foo'
      jsonKey: 'foo'

describe 'DatabaseObjectRegistry', ->
  beforeEach ->
    DatabaseObjectRegistry.unregister("GoodTest")

  it "throws an error if the constructor isn't a Model", ->
    expect( -> DatabaseObjectRegistry.register()).toThrow()
    expect( -> DatabaseObjectRegistry.register(BadTest)).toThrow()

  it "can register constructors", ->
    expect( -> DatabaseObjectRegistry.register(GoodTest)).not.toThrow()
    expect(DatabaseObjectRegistry._constructors["GoodTest"]).toBe GoodTest

  it "Retrurns a map of constructors", ->
    DatabaseObjectRegistry.register(GoodTest)
    map = DatabaseObjectRegistry.classMap()
    expect(map.GoodTest).toBe GoodTest

  it "Tests if a constructor is in the registry", ->
    DatabaseObjectRegistry.register(GoodTest)
    expect(DatabaseObjectRegistry.isInRegistry("GoodTest")).toBe true

  it "deserializes the objects for a constructor", ->
    DatabaseObjectRegistry.register(GoodTest)
    obj = DatabaseObjectRegistry.deserialize("GoodTest", foo: "bar")
    expect(obj instanceof GoodTest).toBe true
    expect(obj.foo).toBe "bar"

  it "throws an error if the object can't be deserialized", ->
    expect( -> DatabaseObjectRegistry.deserialize("GoodTest", foo: "bar")).toThrow()
