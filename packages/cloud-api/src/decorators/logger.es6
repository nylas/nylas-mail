export default function registerLoggerDecorator(server) {
  server.decorate('request', 'logger', (request) => {
    let logger = global.Logger;
    const {account} = request.auth.credentials || {}
    if (request.auth.credentials) {
      logger = logger.forAccount(account)
    }
    return logger.child({endpoint: request.info.path})
  }, {apply: true});
}
