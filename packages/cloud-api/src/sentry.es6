// Widely inspired by https://github.com/bendrucker/hapi-raven

const Raven = require('raven')

exports.register = (server, options, next) => {
  Raven.config(options.dsn, options.client).install();
  server.expose('client', Raven);
  server.on('request-error', (request, err) => {
    const baseUrl = request.info.uri ||
      request.info.host && `${server.info.protocol}://${request.info.host}` ||
      server.info.uri

    Raven.captureException(err, {
      request: {
        method: request.method,
        query_string: request.query,
        headers: request.headers,
        cookies: request.state,
        url: baseUrl + request.path,
      },
      extra: {
        timestamp: request.info.received,
        id: request.id,
        remoteAddress: request.info.remoteAddress,
      },
      tags: options.tags,
    })
  })

  next();
}

exports.register.attributes = {
  name: 'sentry-plugin',
  version: '1.0.0',
}

exports.captureException = Raven.captureException
