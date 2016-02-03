import _ from 'underscore'
import Rx from 'rx-lite'
import {
  Model,
  Actions,
  Metadata,
  DatabaseStore,
  SyncbackMetadataTask} from 'nylas-exports'

/**
 * CloudStorage lets you associate metadata with any Nylas API object.
 *
 * That associated data is automatically stored in the cloud and synced
 * with the local database.
 *
 * You can also get associated data and live-subscribe to associated data.
 *
 * On the Nylas API server this is backed by the `/metadata` endpoint.
 *
 * It is automatically locally replicated and synced with the `Metadata`
 * Database table.
 *
 * Every interaction with the metadata service is automatically scoped
 * by both your unique Plugin ID.
 *
 * You must asscoiate with pre-existing objects that inherit from `Model`.
 * We will extract the appropriate `accountId` from those objects to
 * correctly associate your data.
 *
 * You can observe one or more objects and treat them as live,
 * asynchronous event streams. We use the `Rx.Observable` interface for
 * this.
 *
 * Under the hood the observables are hooked up to our delta streaming
 * endpoint via Database events.
 *
 * ## Example Usage:
 *
 * In /My-Plugin/lib/main.es6
 *
 * ```
 * activate(localState, cloudStorage) {
 *   DatabaseStore.findBy(Thread, "some_thread_id").then((thread) => {
 *
 *     const data = { foo: "bar" }
 *     cloudStorage.associateMetadata({objects: [thread], data: data})
 *
 *     cloudStorage.getMetadata({objects: [thread]}).then((metadata) => {
 *       console.log(metadata[0]);
 *     });
 *
 *     const observer = cloudStorage.observeMetadata({objects: [thread]})
 *     this.subscription = observer.subscribe((newMetadata) => {
 *       console.log("New Metadata!", newMetadata[0])
 *     });
 *   });
 * }
 *
 * deactivate() {
 *   this.subscription.dispose()
 * }
 * ```
 *
 * A CloudStorage instance is a pre-scoped helper to allow plugins to
 * interface with a server-side key-value store.
 *
 * When you `associateMetadata` we generate a `SyncbackMetadataTask`
 * pre-scoped with the `pluginId`.
 * @class CloudStorage
 */
export default class CloudStorage {

  // You never need to instantiate new instances of `CloudStorage`. The
  // Nylas package manager will take care of this.
  constructor(pluginId) {
    this.pluginId = pluginId
    this.applicationId = pluginId
  }

  /**
   * Associates one or more {Model}-inheriting objects with arbitrary
   * `data`. This is automatically persisted to both the `Database` and a
   * the `/metadata` endpoint on the Nylas API
   *
   * @param {object} props - props for `associateMetadata`
   * @param {array} props.objects - an array of one or more objects to
   * associate with the same metadata. These are objects pulled out of the
   * Database.
   * @param {object} props.data - arbitray JSON-serializable data.
   */
  associateMetadata({objects, data}) {
    const objectsToAssociate = this._resolveObjects(objects)
    DatabaseStore.findAll(Metadata,
                         {objectId: _.pluck(objectsToAssociate, "id")})
    .then((existingMetadata = []) => {
      const metadataByObjectId = {}
      for (const m of existingMetadata) {
        metadataByObjectId[m.objectId] = m
      }

      const metadata = []
      for (const objectToAssociate of objectsToAssociate) {
        let metadatum = metadataByObjectId[objectToAssociate.id]
        if (!metadatum) {
          metadatum = this._newMetadataObject(objectToAssociate)
        } else {
          metadatum = this._validateMetadatum(metadatum, objectToAssociate)
        }
        metadatum.value = data
        metadata.push(metadatum)
      }

      return DatabaseStore.inTransaction((t) => {
        return t.persistModels(metadata).then(() => {
          return this._syncbackMetadata(metadata)
        })
      });
    })
  }

  /**
   * Get the metadata associated with one or more objects.
   *
   * @param {object} props - props for `getMetadata`
   * @param {array} props.objects - an array of one or more objects to
   * load metadata for (if there is any)
   * @returns Promise that resolves to an array of zero or more matching
   * {Metadata} objects.
   */
  getMetadata({objects}) {
    const associatedObjects = this._resolveObjects(objects)
    return DatabaseStore.findAll(Metadata,
                         {objectId: _.pluck(associatedObjects, "id")})
  }

  /**
   * Observe the metadata on a set of objects via an RX.Observable
   *
   * @param {object} props - props for `getMetadata`
   * @param {array} props.objects - an array of one or more objects to
   * load metadata for (if there is any)
   * @returns Rx.Observable object that you can call `subscribe` on to
   * subscribe to any changes on the matching query. The onChange callback
   * you pass to subscribe will be passed an array of zero or more
   * matching {Metadata} objects.
   */
  observeMetadata({objects}) {
    const associatedObjects = this._resolveObjects(objects)
    const q = DatabaseStore.findAll(Metadata,
                         {objectId: _.pluck(associatedObjects, "id")})
    return Rx.Observable.fromQuery(q)
  }

  _syncbackMetadata(metadata) {
    for (const metadatum of metadata) {
      const task = new SyncbackMetadataTask({
        clientId: metadatum.clientId,
      });
      Actions.queueTask(task)
    }
  }

  _newMetadataObject(objectToAssociate) {
    return new Metadata({
      applicationId: this.applicationId,
      objectType: this._typeFromObject(objectToAssociate),
      objectId: objectToAssociate.id,
      accountId: objectToAssociate.accountId,
    });
  }

  _validateMetadatum(metadatum, objectToAssociate) {
    const toMatch = {
      applicationId: this.applicationId === metadatum.applicationId,
      objectType: this._typeFromObject(objectToAssociate) === metadatum.objectType,
      objectId: objectToAssociate.id === metadatum.objectId,
      accountId: objectToAssociate.accountId === metadatum.accountId,
    }
    if (_.every(toMatch, (match) => {return match})) {
      return metadatum
    }

    NylasEnv.emitError(new Error(`Metadata object ${metadatum.id} doesn't match data for associated object ${objectToAssociate.id}. Automatically correcting to match.`, toMatch))
    const json = this._newMetadataObject(objectToAssociate).toJSON()
    metadatum.fromJSON(json)
    return metadatum
  }

  _typeFromObject(object) {
    return object.constructor.name.toLowerCase()
  }

  _resolveObjects(objects) {
    const isModel = (obj) => {return obj instanceof Model}
    if (isModel(objects)) {
      return [objects]
    } else if (_.isArray(objects) && objects.length > 0 && _.every(objects, isModel)) {
      return objects
    }
    throw new Error("Must pass one or more `Model` objects to associate")
  }
}
