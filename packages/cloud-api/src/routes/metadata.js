const Joi = require('joi');
const Serialization = require('../serialization');
const {DatabaseConnector} = require('cloud-core');

function upsertMetadata(account, objectId, pluginId, version, data) {
  return DatabaseConnector.forShared().then(({Metadata}) => {
    return Metadata.find({
      accountId: account.id,
      objectId: objectId,
      pluginId: pluginId,
    }).then((existing) => {
      if (existing) {
        if (existing.version / 1 !== version / 1) {
          return Promise.reject(new Error("Version Conflict"));
        }
        existing.data = data;
        return existing.save();
      }
      return Metadata.create({
        accountId: account.id,
        objectId: objectId,
        pluginId: pluginId,
        version: 0,
        data: data,
      })
    })
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
          accountId: account.id,
          limit: request.query.limit,
          offset: request.query.offset,
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
          version: Joi.number().integer(),
          value: Joi.string(),
        },
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;
      const {version, value} = request.payload;
      const {pluginId, objectId} = request.params;

      upsertMetadata(account, objectId, pluginId, version, value)
      .then((metadata) => {
        reply(Serialization.jsonStringify(metadata));
      })
      .catch((err) => {
        reply({error: err.toString()}).code(409);
      })
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
          version: Joi.number().integer(),
        },
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;
      const {version} = request.payload;
      const {pluginId, objectId} = request.params;

      upsertMetadata(account, objectId, pluginId, version, null)
      .then((metadata) => {
        reply(Serialization.jsonStringify(metadata));
      })
      .catch((err) => {
        reply({error: err.toString()}).code(409);
      })
    },
  })
};
