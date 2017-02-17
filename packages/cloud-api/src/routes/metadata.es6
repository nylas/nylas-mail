const Joi = require('joi');
const {DatabaseConnector} = require('cloud-core');
const Serialization = require('../serialization');
const Sentry = require('../sentry')

function upsertMetadata({account, objectId, objectType, pluginId, version, value, expiration}) {
  return DatabaseConnector.forShared().then(({Metadata}) => {
    return Metadata.find({
      where: {
        accountId: account.id,
        objectId: objectId,
        objectType: objectType,
        pluginId: pluginId,
      },
    }).then((existing) => {
      if (existing) {
        if (existing.version / 1 !== version / 1) {
          return Promise.reject(new Error("Version Conflict"));
        }
        existing.value = value;
        existing.expiration = expiration;
        return existing.save();
      }
      return Metadata.create({
        accountId: account.id,
        objectId: objectId,
        objectType: objectType,
        pluginId: pluginId,
        version: 0,
        value: value,
        expiration: expiration,
      })
    })
  })
}

async function upsertThreadMetadata(args) {
  const {messageIds, account, pluginId, expiration} = args
  let {objectId, value, version} = args
  // Thread ids can be any of their message ids prefixed with "t:", so we need
  // to check all of them
  const possibleIds = messageIds.map(msgId => `t:${msgId}`)
  const {Metadata} = await DatabaseConnector.forShared()
  const existing = await Metadata.findAll({
    where: {
      objectId: possibleIds,
      accountId: account.id,
      objectType: 'thread',
      pluginId: pluginId,
    },
    order: [['updatedAt', 'ASC']], // important for merging in the right order
  })

  if (existing.length > 0) {
    // There is metadata for an equivalent thread already. Update this metadata
    // instead of creating a new one.
    objectId = existing[0].objectId;
    version = existing[0].version

    if (existing.length > 1) {
      // There's more that one metadata entry for equivalent threads. We need
      // to merge these all back together.
      const values = existing.map(metadata => metadata.value);
      const keys = values.reduce((result, item) => result.concat(Object.keys(item)), [])
      const keySet = new Set(keys)
      if (keySet.size !== keys.length) {
        // This should be very rare, but data may be incorrectly overwritten here.
        Sentry.captureException(new Error("Key conflict while merging thread metadata"), {
          pluginId: pluginId,
          accountId: account.id,
        })
      }
      // Assign the metadata values such that the latest updates are applied last.
      value = Object.assign({}, ...values, value)
      // Delete these metadata, excpet for the one that we will update
      await Promise.all(existing.filter(metadata => metadata.objectId !== objectId)
        .map(metadata => metadata.destroy()))
    }
  }

  return upsertMetadata({
    account,
    objectId,
    pluginId,
    version,
    value,
    expiration,
    objectType: 'thread',
  })
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/metadata`,
    config: {
      description: `metadata`,
      notes: 'Notes go here',
      tags: ['metadata'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Metadata')
        ),
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;

      DatabaseConnector.forShared().then(({Metadata}) => {
        Metadata.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
          where: {
            accountId: account.id,
          },
        }).then((items) => {
          reply(Serialization.jsonStringify(items));
        })
      })
    },
  });

  server.route({
    method: ['PUT', 'POST'],
    path: `/metadata/{objectId}/{pluginId}`,
    config: {
      description: `Update metadata`,
      tags: ['metadata'],
      validate: {
        params: {
          objectId: Joi.string(),
          pluginId: Joi.string(),
        },
        payload: {
          objectType: Joi.string().required(),
          version: Joi.number().integer().required(),
          value: Joi.string().required(),
          messageIds: Joi.array().items(Joi.string()),
        },
      },
    },
    handler: async (request, reply) => {
      try {
        const {account} = request.auth.credentials;
        const {objectType, messageIds, version} = request.payload;
        let {value} = request.payload;
        const {pluginId, objectId} = request.params;
        try {
          value = JSON.parse(value);
        } catch (e) {
          throw new Error("Invalid Request: `value` is not a parseable JSON string")
        }
        let expiration = null;
        if (value.expiration) {
          expiration = new Date(value.expiration);
          if (isNaN(expiration.valueOf())) {
            throw new Error("Invalid Request: `expiration` is not a parseable date")
          }
        }

        let metadata;
        if (objectType === "thread") {
          metadata = await upsertThreadMetadata({
            account,
            objectId,
            pluginId,
            version,
            value,
            expiration,
            messageIds,
          })
        } else {
          metadata = await upsertMetadata({
            account,
            objectId,
            objectType,
            pluginId,
            version,
            value,
            expiration,
          })
        }

        reply(Serialization.jsonStringify(metadata));
      } catch (error) {
        if (error.message.includes('Invalid Request')) {
          reply({error: error.toString()}).code(400);
        } else if (error.message.includes('Version Conflict')) {
          reply({error: error.toString()}).code(409);
        } else {
          reply({error: error.toString()}).code(500)
        }
      }
    },
  })

  server.route({
    method: 'DELETE',
    path: `/metadata/{objectId}/{pluginId}`,
    config: {
      description: `Delete metadata`,
      tags: ['metadata'],
      validate: {
        params: {
          objectId: Joi.number().integer(),
          pluginId: Joi.string(),
        },
        payload: {
          objectType: Joi.string(),
          version: Joi.number().integer(),
        },
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;
      const {version, objectType} = request.payload;
      const {pluginId, objectId} = request.params;

      upsertMetadata({account, objectId, objectType, pluginId, version, value: null})
      .then((metadata) => {
        reply(Serialization.jsonStringify(metadata));
      })
      .catch((err) => {
        reply({error: err.toString()}).code(409);
      })
    },
  })
};
