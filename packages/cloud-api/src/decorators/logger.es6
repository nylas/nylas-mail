export default function registerLoggerDecorator(server) {
  server.decorate('request', 'logger', (request) => {
    if (request.auth.credentials) {
      return global.Logger.forAccount(request.auth.credentials)
    }
    return global.Logger
  }, {apply: true});
}
