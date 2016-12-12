import {Model, Attributes} from 'nylas-exports'


class SalesforceSchema extends Model {

  static attributes = {
    id: Attributes.String({
      queryable: true,
      modelKey: 'id',
      jsonKey: 'id',
    }),

    schemaType: Attributes.String({
      queryable: true,
      modelKey: 'schemaType',
      jsonKey: 'schemaType',
    }),

    objectType: Attributes.String({
      queryable: true,
      modelKey: 'objectType',
      jsonKey: 'objectType',
    }),

    fieldsets: Attributes.Object({
      modelKey: 'fieldsets',
      jsonKey: 'fieldsets',
    }),

    createdAt: Attributes.DateTime({
      queryable: true,
      modelKey: 'createdAt',
      jsonKey: 'createdAt',
    }),
  }
}

export default SalesforceSchema
