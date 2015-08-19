_ = require 'underscore'
ipc = require 'ipc'
Model = null
SerializableRegistry = require './serializable-registry'

class DatabaseObjectRegistry extends SerializableRegistry

  classMap: -> return @_constructors

  register: (constructor) ->
    Model ?= require './flux/models/model'
    if constructor?.prototype instanceof Model
      super
    else
      throw new Error("You must register a Database Object class with this registry", constructor)

module.exports = new DatabaseObjectRegistry()
