Utils = require '../models/utils'

###
DatabaseChangeRecord is the object emitted from the DatabaseStore when it triggers.
The DatabaseChangeRecord contains information about what type of model changed,
and references to the new model values. All mutations to the database produce these
change records.
###
class DatabaseChangeRecord

  constructor: (options) ->
    @options = options

    # When DatabaseChangeRecords are sent over IPC to other windows, their object
    # payload is sub-serialized into a JSON string. This means that we can wait
    # to deserialize models until someone in the window asks for `change.objects`
    @_objects = options.objects
    @_objectsString = options.objectsString

    Object.defineProperty(@, 'type', {
      get: -> options.type
    })
    Object.defineProperty(@, 'objectClass', {
      get: -> options.objectClass
    })
    Object.defineProperty(@, 'objects', {
      get: ->
        @_objects ?= Utils.deserializeRegisteredObjects(@_objectsString)
        @_objects
    })

  toJSON: =>
    @_objectsString ?= Utils.serializeRegisteredObjects(@_objects)

    type: @type
    objectClass: @objectClass
    objectsString: @_objectsString

module.exports = DatabaseChangeRecord
