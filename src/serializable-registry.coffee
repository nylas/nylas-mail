_ = require 'underscore'

# This keeps track of constructors so we know how to inflate serialized
# objects.
#
# If 3rd party packages want to register new inflatable models, they can
# use `register` and pass the constructor along with the name.
#
# Note that there is one registry per window.
class SerializableRegistry
  constructor: ->
    # A mapping of the string name and the constructor class.
    @_constructors = {}

  get: (name) -> @_constructors[name]

  isInRegistry: (name) -> @_constructors[name]?

  deserialize: (name, data) ->
    if _.isString(data)
      data = JSON.parse(data)

    constructor = @get(name)

    if not _.isFunction(constructor)
      throw new Error "Unsure of how to inflate #{JSON.stringify(data)}"

    object = new constructor()
    object.fromJSON(data)

    return object

  register: (constructor) ->
    @_constructors[constructor.name] = constructor

  unregister: (name) -> delete @_constructors[name]

module.exports = SerializableRegistry
