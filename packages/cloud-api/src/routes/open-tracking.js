const Joi = require('joi')
const Base64 = require('js-base64').Base64
const {DatabaseConnector} = require('cloud-core')

const PLUGIN_NAME = 'open-tracking'

function updateMetadata(metadata, recipient) {
  const FIVE_MINUTES = 60 * 5 // in seconds
  const timestamp = Date.now() / 1000

  // Iterate backwards until you reach older timestamps or find the same
  // recipient with a timestamp newer than five minutes
  for (const open of metadata.value.open_data.slice().reverse()) {
    if (timestamp - open.timestamp > FIVE_MINUTES) {
      break
    }
    if (open.recipient === recipient) {
      return
    }
  }

  metadata.value.open_count += 1
  metadata.value.open_data.append({
    timestamp: timestamp,
    recipient: recipient,
  })
  metadata.save()
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/open/{accountId}/{messageId}`,
    config: {
      description: `open-tracking`,
      notes: 'Notes go here',
      tags: ['open-tracking'],
      validate: {
        params: {
          accountId: Joi.string().required(),
          messageId: Joi.string().required(),
        },
        query: {
          r: Joi.string(),
        },
      },
    },
    handler: (request, reply) => {
      const {accountId, messageId} = request.params
      const {r} = request.query
      const recipient = r ? Base64.decode(r) : null

      DatabaseConnector.forShared().then(({Metadata}) => {
        Metadata.find({
          where: {
            accountId: accountId,
            pluginId: PLUGIN_NAME,
            objectId: messageId,
            objectType: 'Message',
          },
        }).then((metadata) => {
          try {
            updateMetadata(metadata, recipient)
          } finally {
            reply.file('../../static/images/transparent.gif')
            .header('Cache-Control', 'no-cache max-age=0')
          }
        })
      })
    },
  })
}
