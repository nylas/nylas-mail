import _ from 'underscore';
import {
  Actions,
  NylasAPI,
  DatabaseStore,
  MailRulesProcessor,
} from 'nylas-exports';

/**
 * This injests deltas from multiple sources. One is from local-sync, the
 * other is from n1-cloud. Both sources use
 * isomorphic-core/src/delta-stream-builder to generate the delta stream.
 *
 * In both cases we are given the JSON serialized form of a `Transaction`
 * model. An example Thread delta would look like:
 *
 *   modelDelta = {
 *     id: 518,
 *     event: "modify",
 *     object: "thread",
 *     objectId: 2887,
 *     changedFields: ["subject", "unread"],
 *     attributes: {
 *       id: 2887,
 *       object: 'thread',
 *       account_id: 2,
 *       subject: "Hello World",
 *       unread: true,
 *       ...
 *     }
 *   }
 *
 * An example Metadata delta would look like:
 *
 *   metadataDelta = {
 *     id: 519,
 *     event: "create",
 *     object: "metadata",
 *     objectId: 8876,
 *     changedFields: ["version", "object"],
 *     attributes: {
 *       id: 8876,
 *       value: {link_clicks: 1},
 *       object: "metadata",
 *       version: 2,
 *       plugin_id: "link-tracking",
 *       object_id: 2887,
 *       object_type: "thread"
 *       account_id: 2,
 *     }
 *   }
 *
 * The `object` may be "thread", "message", "metadata", or any other model
 * type we support
 */
class DeltaProcessor {
  process = (rawDeltas = []) => {
    Promise.resolve(rawDeltas)
    .then(this._decorateDeltas)
    .then(this._notifyOfRawDeltas)
    .then(this._extractDeltaTypes)
    .then(({modelDeltas, metadataDeltas, accountDeltas}) => {
      return Promise.resolve()
      .then(() => this._handleAccountDeltas(accountDeltas))
      .then(() => this._saveModels(modelDeltas))
      .then(() => this._saveMetadata(metadataDeltas))
      .then(() => this._notifyOfNewMessages(modelDeltas))
    })
    .finally(() => Actions.longPollProcessedDeltas())
  }

  /**
   * Create a (non-enumerable) reference from the attributes which we
   * carry forward back to their original deltas. This allows us to
   * mark the deltas that the app ignores later in the process.
   */
  _decorateDeltas = (rawDeltas) => {
    rawDeltas.forEach((delta) => {
      if (!delta.attributes) return;
      Object.defineProperty(delta.attributes, '_delta', {
        get() { return delta; },
      });
    })
    return rawDeltas
  }

  _notifyOfRawDeltas = (rawDeltas) => {
    Actions.longPollReceivedRawDeltas(rawDeltas);
    Actions.longPollReceivedRawDeltasPing(rawDeltas.length);
    return rawDeltas
  }

  _extractDeltaTypes = (rawDeltas) => {
    const modelDeltas = []
    const accountDeltas = []
    const metadataDeltas = []
    rawDeltas.forEach((delta) => {
      if (delta.object === "metadata") {
        metadataDeltas.push(delta)
      } else if (delta.object === "account") {
        accountDeltas.push(delta)
      } else {
        modelDeltas.push(delta)
      }
    })
    return {modelDeltas, metadataDeltas, accountDeltas}
  }

  _handleAccountDeltas = (accountDeltas) => {
    const {modify} = this._clusterDeltas(accountDeltas);
    if (!modify.account) return;
    for (const accountJSON of _.values(modify.account)) {
      Actions.updateAccount(accountJSON.account_id, {syncState: accountJSON.sync_state});
      if (accountJSON.sync_state !== "running") {
        Actions.recordUserEvent('Account Sync Errored', {
          accountId: accountJSON.account_id,
          syncState: accountJSON.sync_state,
        });
      }
    }
  }

  _saveModels = (modelDeltas) => {
    const {create, modify, destroy} = this._clusterDeltas(modelDeltas);
    const toJSONs = (objs) => _.flatten(_.values(objs).map(_.values))
    return Promise.resolve()
    .then(() =>
      Promise.map(toJSONs(create), NylasAPI._handleModelResponse))
    .then(() =>
      Promise.map(toJSONs(modify), NylasAPI._handleModelResponse))
    .then(() =>
      Promise.map(destroy, this._destroyDeltas))
  }

  _saveMetadata = (deltas) => {
    const {create, modify} = this._clusterDeltas(deltas);

    const allUpdatingMetadata = _.values(create.metadata).concat(_.values(modify.metadata));

    const byObjectType = _.groupBy(allUpdatingMetadata, "object_type")

    return Promise.map(Object.keys(byObjectType), (objType) => {
      const jsons = byObjectType[objType]
      const klass = NylasAPI._apiObjectToClassMap[objType];
      const byObjId = _.pluck(jsons, "object_id")

      return DatabaseStore.inTransaction(t => {
        return t.findAll(klass, {id: Object.keys(byObjId)})
        .then((models) => {
          if (!models || models.length === 0) return Promise.resolve()
          models.forEach((model) => {
            const mdJSON = byObjId[model.id]
            const modelWithMetadata = model.applyPluginMetadata(mdJSON.plugin_id, mdJSON.value);
            const localMetadatum = modelWithMetadata.metadataObjectForPluginId(mdJSON.plugin_id);
            localMetadatum.version = mdJSON.version;
          })
          return t.persistModels(models)
        });
      });
    })
  }

  /**
   * We need to re-fetch the models since they may have metadata attached
   * to them now
   */
  _notifyOfNewMessages = (modelDeltas) => {
    const {create} = this._clusterDeltas(modelDeltas);
    const modelResolvers = {}
    for (const objectType of Object.keys(create)) {
      const klass = NylasAPI._apiObjectToClassMap[objectType];
      if (!klass) {
        throw new Error(`Can't find class for "${objectType}" when attempting to inflate deltas`)
      }
      modelResolvers[objectType] = DatabaseStore.findAll(klass, {
        id: Object.keys(create[objectType]),
      })
    }
    Promise.props(modelResolvers).then((modelsByType) => {
      const allModels = _.flatten(_.values(modelsByType));
      if ((modelsByType.message || []).length > 0) {
        return MailRulesProcessor.processMessages(modelsByType.message || [])
        .finally(() => {
          return Actions.didPassivelyReceiveNewModels(allModels);
        });
      }
      return Promise.resolve()
    })
  }

  /**
   * Group deltas by object type so we can mutate the cache efficiently.
   * NOTE: This code must not just accumulate creates, modifies and
   * destroys but also de-dupe them. We cannot call
   * "persistModels(itemA, itemA, itemB)" or it will throw an exception
   */
  _clusterDeltas(deltas) {
    const create = {};
    const modify = {};
    const destroy = [];
    for (const delta of deltas) {
      if (delta.event === 'create') {
        if (!create[delta.object]) { create[delta.object] = {}; }
        create[delta.object][delta.attributes.id] = delta.attributes;
      } else if (delta.event === 'modify') {
        if (!modify[delta.object]) { modify[delta.object] = {}; }
        modify[delta.object][delta.attributes.id] = delta.attributes;
      } else if (delta.event === 'delete') {
        destroy.push(delta);
      }
    }

    return {create, modify, destroy};
  }

  _destroyDeltas = (destroy) => {
    return Promise.map(destroy, (delta) => {
      const klass = NylasAPI._apiObjectToClassMap[delta.object];
      if (!klass) { return Promise.resolve(); }

      return DatabaseStore.inTransaction(t => {
        return t.find(klass, delta.objectId).then((model) => {
          if (!model) { return Promise.resolve(); }
          return t.unpersistModel(model);
        });
      });
    })
  }
}
export default new DeltaProcessor()
