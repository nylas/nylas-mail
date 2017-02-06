const Joi = require('joi');
const Serialization = require('../serialization');
const {DatabaseConnector} = require('cloud-core');

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
        },
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;
      const {version, value, objectType} = request.payload;
      const {pluginId, objectId} = request.params;
      const jsonValue = JSON.parse(value);
      let expiration = null;
      if (jsonValue.expiration) {
        expiration = new Date(jsonValue.expiration);
      }

      upsertMetadata({
        account,
        objectId,
        objectType,
        pluginId,
        version,
        value: jsonValue,
        expiration})
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
