Tag = require '../../src/flux/models/tag'
Model = require '../../src/flux/models/model'
Attributes = require '../../src/flux/attributes'

class TestModel extends Model
  @attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

TestModel.configureBasic = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

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
    'tags': Attributes.Collection
      queryable: true
      modelKey: 'tags'
      itemClass: Tag


TestModel.configureWithJoinedDataAttribute = ->
  TestModel.additionalSQLiteConfig = undefined
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'body': Attributes.JoinedData
      modelTable: 'TestModelBody'
      modelKey: 'body'


TestModel.configureWithAdditionalSQLiteConfig = ->
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'body': Attributes.JoinedData
      modelTable: 'TestModelBody'
      modelKey: 'body'
  TestModel.additionalSQLiteConfig =
    setup: ->
      ['CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(last_message_timestamp DESC, namespace_id, id)']
    writeModel: jasmine.createSpy('additionalWriteModel')
    deleteModel: jasmine.createSpy('additionalDeleteModel')

module.exports = TestModel
