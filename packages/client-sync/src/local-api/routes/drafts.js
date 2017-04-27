const {MessageUtils, Errors: {APIError}} = require('isomorphic-core')
const Joi = require('joi');

// TODO: This is a placeholder.
module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/drafts',
    config: {
      description: 'Returns drafts.',
      notes: 'Notes go here',
      tags: ['drafts'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
          view: Joi.string().valid('count'),
        },
      },
      response: {
        schema: Joi.array(),
      },
    },
    handler: (request, reply) => {
      reply('[]');
    },
  });

  server.route({
    method: ['PUT', 'POST'],
    path: `/drafts/build`,
    config: {
      description: `Returns a ready-made draft message. Used by our send later plugin.`,
      tags: ['drafts'],
      payload: {
        output: 'data',
        parse: true,
      },
    },
    handler: async (request, reply) => {
      const db = await request.getAccountDatabase();
      const account = request.auth.credentials;

      let sentFolderName;
      let sentFolder;
      let trashFolderName;

      if (account.provider === 'gmail') {
        sentFolder = await db.Label.find({where: {role: 'sent'}});
      } else {
        sentFolder = await db.Folder.find({where: {role: 'sent'}});
      }

      if (sentFolder) {
        sentFolderName = sentFolder.name;
      } else {
        throw new APIError(`Can't find sent folder name.`, 500);
      }

      const trashFolder = await db.Folder.find({where: {role: 'trash'}});

      if (trashFolder) {
        trashFolderName = trashFolder.name;
      } else {
        throw new APIError(`Can't find trash folder name.`, 500);
      }

      const message = await MessageUtils.buildForSend(db, request.payload);
      const ret = Object.assign(message.toJSON(), { sentFolderName, trashFolderName });
      reply(JSON.stringify(ret));
    },
  });
}
