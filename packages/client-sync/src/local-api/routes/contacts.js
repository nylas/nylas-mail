const Joi = require('joi');
const Serialization = require('../serialization');
const moment = require('moment-timezone');

const LOOKBACK_TIME = moment.duration(2, 'years').asMilliseconds();
const MIN_MESSAGE_WEIGHT = 0.01;

const getMessageWeight = (message, now) => {
  const timeDiff = now - message.date.getTime();
  const weight = 1.0 - (timeDiff / LOOKBACK_TIME);
  return Math.max(weight, MIN_MESSAGE_WEIGHT);
};

const calculateContactScores = (messages, result) => {
  const now = Date.now();
  for (const message of messages) {
    const weight = getMessageWeight(message, now);
    for (const recipient of message.getRecipients()) {
      const email = recipient.email.toLowerCase();
      result[email] = result[email] ? (result[email] + weight) : weight;
    }
  }
};

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/contacts',
    config: {
      description: 'Returns an array of contacts',
      notes: 'Notes go here',
      tags: ['contacts'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Contact')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Contact} = db;
        Contact.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
        }).then((contacts) => {
          reply(Serialization.jsonStringify(contacts))
        })
      })
    },
  })

  server.route({
    method: 'GET',
    path: '/contacts/{id}',
    config: {
      description: 'Returns a contact with specified id.',
      notes: 'Notes go here',
      tags: ['contacts'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
      response: {
        schema: Serialization.jsonSchema('Contact'),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then(({Contact}) => {
        const {params: {id}} = request

        Contact.findOne({where: {id}}).then((contact) => {
          if (!contact) {
            return reply.notFound(`Contact ${id} not found`)
          }
          return reply(Serialization.jsonStringify(contact))
        })
        .catch((error) => {
          request.info(error, 'Error fetching contacts')
        })
      })
    },
  })

  // TODO: This is a placeholder
  server.route({
    method: 'GET',
    path: '/contacts/rankings',
    config: {
      description: 'Returns contact rankings.',
      notes: 'Notes go here',
      tags: ['contacts'],
    },
    handler: async (request, reply) => {
      const db = await request.getAccountDatabase()
      const {Message, Label, Folder} = db;

      const result = {};
      let lastID = 0;

      while (true) {
        const messages = await Message.findAll({
          attributes: ['rowid', 'id', 'to', 'cc', 'bcc', 'date'],
          // We mark both Label and Folder as not required because we don't know
          // whether the account uses folders or labels.
          include: [
            {
              model: Label,
              attributes: ['id', 'role'],
              where: {role: 'sent'},
              required: false,                // This triggers a left outer join.
            },
            {
              model: Folder,
              attributes: ['id', 'role'],
              where: {role: 'sent'},
              required: false,                // This triggers a left outer join.
            },
          ],
          where: {
            'isDraft': false,                   // Don't include unsent things.

            // Because we did a left outer join on the Folder and Label tables,
            // we can get back records that have null for both the Folder and the
            // Label (i.e. all things that aren't in the Sent folder). So we need
            // to require that either the label ID or the folder ID is not null
            // (i.e. that the message is in the Sent folder)
            '$or': [
              {'$labels.id$': {$ne: null}},
              {'$folder.id$': {$ne: null}},
            ],
            '$message.rowid$': {$gt: lastID},
          },
          // We don't use the `limit` option here because it causes sequelize
          // to generate a subquery that doesn't have access to the joined
          // labels/folders, causing a SQLite error to be thrown.
          order: 'message.rowid ASC LIMIT 500',
        });

        if (messages.length === 0) {
          break;
        }

        calculateContactScores(messages, result);
        lastID = Math.max(...messages.map(m => m.dataValues.rowid));
      }
      reply(JSON.stringify(Object.entries(result)));
    },
  })
}
