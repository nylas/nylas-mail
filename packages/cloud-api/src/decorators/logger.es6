export default function registerLoggerDecorator(server) {
  server.decorate('request', 'logger', (request) => {
    return global.Logger.child({
      http_method: request.method.toUpperCase(),
      remote_addr: request.info.remoteAddress,
      remote_port: request.info.remotePort,
      // path includes query params; pathname does not
      endpoint: request.url.pathname,
      http_request: request.url.path,
      // http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-request-tracing.html
      request_uid: request.headers['X-Amzn-Trace-Id'] || request.id,
    })
  }, {apply: true});
}
