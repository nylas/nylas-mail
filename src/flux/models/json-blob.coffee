_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

class JSONBlob extends Model
  @attributes:
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'

    'serverId': Attributes.ServerId
      modelKey: 'serverId'
      jsonKey: 'server_id'

    'json': Attributes.Object
      modelKey: 'json'
      jsonKey: 'json'

  Object.defineProperty @prototype, 'key',
    get: -> @serverId
    set: (val) -> @serverId = val

  Object.defineProperty @prototype, 'clientId',
    get: -> @serverId
    set: (val) -> @serverId = val

module.exports = JSONBlob
