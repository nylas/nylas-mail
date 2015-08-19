Model = require './model'
Attributes = require '../attributes'
{generateTempId} = require './utils'

Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}

class Metadata extends Model
  @attributes:
    'type': Attributes.String
      queryable: true
      modelKey: 'type'
      jsonKey: 'type'

    'publicId': Attributes.String
      queryable: true
      modelKey: 'publicId'
      jsonKey: 'publicId'

    'key': Attributes.String
      queryable: true
      modelKey: 'key'
      jsonKey: 'key'

    'value': Attributes.Object
      modelKey: 'value'
      jsonKey: 'value'

  @getter 'id', ->
    if @type and @publicId and @key
      @id = "#{@type}/#{@publicId}/#{@key}"
    else
      @id = generateTempId()

module.exports = Metadata
