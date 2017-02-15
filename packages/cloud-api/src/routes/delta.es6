import Joi from 'joi';
import {DatabaseConnector, PubsubConnector} from 'cloud-core';
import {DeltaStreamBuilder} from 'isomorphic-core'

export default function registerDeltaRoutes(server) {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    config: {
      validate: {
        query: {
          cursor: Joi.string().required(),
        },
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;

      request.logger.info("Starting /delta/streaming")

      DeltaStreamBuilder.buildAPIStream(request, {
        accountId: account.id,
        cursor: request.query.cursor,
        databasePromise: DatabaseConnector.forShared(),
        deltasSource: PubsubConnector.observeDeltas(account.id),
      }).then((stream) => {
        reply(stream)
      });
    },
  });

  server.route({
    method: 'POST',
    path: '/delta/latest_cursor',
    handler: (request, reply) => {
      DeltaStreamBuilder.buildCursor({
        databasePromise: DatabaseConnector.forShared(),
      }).then((cursor) => {
        reply({cursor})
      });
    },
  });
}
