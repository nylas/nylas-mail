import Model from './model'
import Attributes from '../attributes'

/**
 Cloud-persisted data that is associated with a single Nylas API object
 (like a `Thread`, `Message`, or `Account`).

 Each Nylas API object can have exactly one `Metadata` object associated
 with it. If you update the metadata object on an existing associated
 Nylas API object, it will override the previous `value`
*/
export default class Metadata extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    /*
    The unique ID of the plugin that owns this Metadata item. The Nylas
    N1 Database holds the Metadata objects for many of its installed
    plugins.
    */
    applicationId: Attributes.String({
      queryable: true,
      modelKey: 'applicationId',
      jsonKey: 'application_id',
    }),

    /*
    The type of Nylas API object this Metadata item is associated with.
    Should be the lowercase singular classname of an object like
    `thread` or `message`, or `account`
    */
    objectType: Attributes.String({
      queryable: true,
      modelKey: 'objectType',
      jsonKey: 'object_type',
    }),

    // The unique public ID of the Nylas API object.
    objectId: Attributes.String({
      queryable: true,
      modelKey: 'objectId',
      jsonKey: 'object_id',
    }),

    /*
    The current version of this `Metadata` object. Note that since Nylas
    API objects can only have exactly one `Metadata` object attached to
    it, any action preformed on the `Metadata` of a Nylas API object
    will override the existing object and bump the `version`.
    */
    version: Attributes.Number({
      modelKey: 'version',
      jsonKey: 'version',
    }),

    // A generic value that can be any string-serializable object.
    value: Attributes.Object({
      modelKey: 'value',
      jsonKey: 'value',
    }),
  });
}
