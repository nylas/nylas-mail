Label = require '../../src/flux/models/label'
Model = require '../../src/flux/models/model'
Attributes = require '../../src/flux/attributes'

class TestModel extends Model
  @attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'

    'serverId': Attributes.ServerId
      queryable: true
      modelKey: 'serverId'
      jsonKey: 'server_id'

TestModel.configureBasic = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'
    'serverId': Attributes.ServerId
      queryable: true
      modelKey: 'serverId'
      jsonKey: 'server_id'

TestModel.configureWithAllAttributes = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'datetime': Attributes.DateTime
      queryable: true
      modelKey: 'datetime'
    'string': Attributes.String
      queryable: true
      modelKey: 'string'
      jsonKey: 'string-json-key'
    'boolean': Attributes.Boolean
      queryable: true
      modelKey: 'boolean'
    'number': Attributes.Number
      queryable: true
      modelKey: 'number'
    'other': Attributes.String
      modelKey: 'other'

TestModel.configureWithCollectionAttribute = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'
    'serverId': Attributes.ServerId
      queryable: true
      modelKey: 'serverId'
      jsonKey: 'server_id'
    'labels': Attributes.Collection
      queryable: true
      modelKey: 'labels'
      itemClass: Label


TestModel.configureWithJoinedDataAttribute = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'
    'serverId': Attributes.ServerId
      queryable: true
      modelKey: 'serverId'
      jsonKey: 'server_id'
    'body': Attributes.JoinedData
      modelTable: 'TestModelBody'
      modelKey: 'body'


TestModel.configureWithAdditionalSQLiteConfig = ->
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'clientId': Attributes.String
      modelKey: 'clientId'
      jsonKey: 'client_id'
    'serverId': Attributes.ServerId
      modelKey: 'serverId'
      jsonKey: 'server_id'
    'body': Attributes.JoinedData
      modelTable: 'TestModelBody'
      modelKey: 'body'
  TestModel.additionalSQLiteConfig =
    setup: ->
      ['CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(last_message_received_timestamp DESC, account_id, id)']

module.exports = TestModel
