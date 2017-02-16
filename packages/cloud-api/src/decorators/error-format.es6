export default function registerErrorFormatDecorator(server) {
  server.ext('onPreResponse', (request, reply) => {
    if (request.response && request.response.isBoom) {
      request.response.reformat();
      return reply.continue()
    }
    return reply.continue()
  })
}
