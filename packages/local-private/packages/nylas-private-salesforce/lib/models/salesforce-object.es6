import {Model, Attributes} from 'nylas-exports'

class SalesforceObject extends Model {

  static searchable = true

  static searchFields = ['content']

  // This intentionally does NOT use _.extend(... Model.Attributes)
  // because we do NOT want most of those attributes.
  // So, we pick the relevant attributes by hand.
  static attributes = {
    id: Attributes.String({
      queryable: true,
      modelKey: 'id',
    }),

    clientId: Attributes.String({
      queryable: true,
      modelKey: 'clientId',
      jsonKey: 'client_id',
    }),

    serverId: Attributes.ServerId({
      queryable: true,
      modelKey: 'serverId',
      jsonKey: 'server_id',
    }),

    type: Attributes.String({
      queryable: true,
      modelKey: 'type',
      jsonKey: 'type',
    }),

    name: Attributes.String({
      queryable: true,
      modelKey: 'name',
      jsonKey: 'name',
    }),

    // Can optionally be used to query for objects if the name is not
    // sufficient. For example, a Contact object might want to put the
    // `email` field here. A Task might want to put the `description`
    // field here.
    // We also downcase and trim the data before it goes into the
    // "identifier" field.
    identifier: Attributes.String({
      queryable: true,
      modelKey: 'identifier',
      jsonKey: 'identifier',
    }),

    relatedToId: Attributes.String({
      queryable: true,
      modelKey: 'relatedToId',
      jsonKey: 'relatedToId',
    }),

    updatedAt: Attributes.DateTime({
      queryable: true,
      modelKey: 'updatedAt',
      jsonKey: 'updatedAt',
    }),

    // NOTE: We always expect that rawData is filled with the complete
    // object (not a partial object). We use that to determine if we have
    // enough information to display a SalesforceObject Edit field.
    rawData: Attributes.Object({
      modelKey: 'rawData',
      jsonKey: 'rawData',
    }),

    isSearchIndexed: Attributes.Boolean({
      queryable: true,
      modelKey: 'isSearchIndexed',
      jsonKey: 'is_search_indexed',
      defaultValue: false,
      loadFromColumn: true,
    }),

    // This corresponds to the rowid in the FTS table. We need to use the FTS
    // rowid when updating and deleting items in the FTS table because otherwise
    // these operations would be way too slow on large FTS tables.
    searchIndexId: Attributes.Number({
      modelKey: 'searchIndexId',
      jsonKey: 'search_index_id',
    }),
  }

  static sortOrderAttribute = () => {
    return SalesforceObject.attributes.name
  }

  static naturalSortOrder = () => {
    return SalesforceObject.sortOrderAttribute().descending()
  }

  static additionalSQLiteConfig = {
    setup: () => [
      'CREATE INDEX IF NOT EXISTS TypeIdentifierIndex ON `SalesforceObject` (type, identifier)',
      'CREATE INDEX IF NOT EXISTS TypeRelatedToIdIndex ON `SalesforceObject` (type, relatedToId)',
    ],
  }
}

export default SalesforceObject
