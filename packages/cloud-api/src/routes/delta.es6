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
        const streamTimeout = setTimeout(() => {
          const response = request.raw.res; // request is the hapijs handler request object
          request.logger.info('Delta stream connection timeout.')
          response.end();
        }, DeltaStreamBuilder.DELTA_CONNECTION_TIMEOUT_MS);

        stream.once('end', () => {
          clearTimeout(streamTimeout);
          return stream.close();
        });

        reply(stream)
      });
    },
  });
}
