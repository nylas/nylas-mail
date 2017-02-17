import {MetricsReporter} from 'isomorphic-core'

export default function registerHoneycombRoutes(server) {
  server.route({
    method: 'POST',
    path: '/ingest-metrics',
    handler: (request, reply) => {
      MetricsReporter.sendToHoneycomb(request.payload)
      reply({success: true})
    },
  });
}
