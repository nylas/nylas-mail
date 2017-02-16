import Hapi from 'hapi';
import Boom from 'boom'
import {DatabaseConnector} from 'cloud-core';

const MAX_TIME_BETWEEN_ITERATIONS = 5 * 60 * 1000;

export function setupMonitoring(logger) {
  const server = new Hapi.Server({
    debug: false,
    connections: {
      router: {
        stripTrailingSlash: true,
      },
    },
  });

  server.connection({ port: process.env.PORT || 8080 });

  server.route({
    method: 'GET',
    path: '/ping',
    config: { auth: false },
    handler: async (request, reply) => {
      logger.info('---> Ping DB');
      try {
        const db = await DatabaseConnector.forShared();
        await db.sequelize.query('SELECT 1');

        if (new Date() - global.lastRun >= MAX_TIME_BETWEEN_ITERATIONS) {
          reply(Boom.wrap("Main loop seems to be stuck.", 500));
        } else {
          reply("DB Okay")
        }
      } catch (err) {
        reply(Boom.wrap(err, 500));
      }
    },
  });

  server.start((startErr) => {
    if (startErr) { throw startErr; }
    console.info('Watchdog server running.');
  });
}
