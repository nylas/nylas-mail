import Boom from 'boom'

export default function registerPingRoutes(server) {
  server.route({
    method: 'GET',
    path: '/ping',
    config: { auth: false },
    handler: (request, reply) => {
      request.logger.info('---> Pong 200')
      reply("Pong")
    },
  });

  server.route({
    method: 'GET',
    path: '/ping/400',
    config: { auth: false },
    handler: (request, reply) => {
      request.logger.info('---> Pong 400');
      reply(Boom.badRequest("Pong bad request", {foo: 'bar'}))
    },
  });

  server.route({
    method: 'GET',
    path: '/ping/401',
    config: { auth: false },
    handler: (request, reply) => {
      request.logger.info('---> Pong 401');
      reply(Boom.unauthorized('invalid password', 'sample', { ttl: 0, cache: null, foo: 'bar' }))
    },
  });

  server.route({
    method: 'GET',
    path: '/ping/500',
    config: { auth: false },
    handler: (request, reply) => {
      request.logger.info('---> Pong 500');
      reply(Boom.badImplementation("Broken borked", {bad: "news"}))
    },
  });

  server.route({
    method: 'GET',
    path: '/ping/broken',
    config: { auth: false },
    handler: (request) => {
      request.logger.info('---> Pong broken');
      throw new Error("Broken Code")
    },
  });

  server.route({
    method: 'GET',
    path: '/ping/downstream_error',
    config: { auth: false },
    handler: (request, reply) => {
      request.logger.info('---> Pong downstream error');
      const downstream = new Error("Downstream badness");
      reply(Boom.wrap(downstream, 400, "Extra info here"));
    },
  });
}
