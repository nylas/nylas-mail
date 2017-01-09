const Path = require('path')

export default function registerStaticRoutes(server) {
  server.route({
    method: 'GET',
    path: '/static/{file*}',
    config: {
      auth: false,
    },
    handler: {
      directory: {
        path: Path.join(__dirname, '../../static/'),
        redirectToSlash: true,
        listing: true,
      },
    },
  });
}
