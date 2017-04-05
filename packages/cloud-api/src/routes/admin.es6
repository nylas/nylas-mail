import _ from 'underscore'
import {DatabaseConnector} from 'cloud-core';

export default function registerAdminRoutes(server) {
  server.route({
    method: "GET",
    path: "/admin",
    config: {
      auth: "static-password",
    },
    handler: async (request, reply) => {
      const db = await DatabaseConnector.forShared();
      const jobs = await db.CloudJob.findAll({limit: 1000, order: 'statusUpdatedAt DESC'});
      reply.view('admin', _.groupBy(jobs, "type"));
    },
  })
}
