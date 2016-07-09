module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/ping',
    config: {
      auth: false,
    },
    handler: (request, reply) => {
      request.logger.info('----> Pong!')
      reply("Pong")
    },
  });
};
