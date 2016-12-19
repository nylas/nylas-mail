import LibHoney from 'libhoney'

const honey = new LibHoney({
  writeKey: process.env.HONEY_WRITE_KEY,
  dataset: process.env.HONEY_DATASET,
});

export default function registerHoneycombRoutes(server) {
  server.route({
    method: 'POST',
    path: '/ingest-metrics',
    handler: (request, reply) => {
      honey.sendNow(request.payload);
      reply({success: true})
    },
  });
}
