const Joi = require('joi');


module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/files/{id}/download',
    config: {
      description: 'Returns binary data for file with specified id.',
      notes: 'Notes go here',
      tags: ['files'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase()
      .then((db) => {
        const {params: {id}} = request
        const account = request.auth.credentials

        db.File.findOne({where: {id}})
        .then((file) => {
          if (!file) {
            return reply.notFound(`File ${id} not found`)
          }
          return file.fetch({account, db, logger: request.logger})
          .then((stream) => reply(stream))
        })
        .catch((err) => {
          request.logger.error(err, 'Error downloading file')
          reply(err)
        })
      })
    },
  })
};
