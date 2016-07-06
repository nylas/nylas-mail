module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/ping',
    config: {
      auth: false,
    },
    handler: (request, reply) => {
      console.log("---> Ping!")
      reply("pong")
    },
  });
};
