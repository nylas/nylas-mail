const Joi = require('joi')
const Base64 = require('js-base64').Base64
const {DatabaseConnector} = require('cloud-core')

const PLUGIN_NAME = 'link-tracking'

function updateMetadata(metadata, recipient, linkIdx) {
  const FIVE_MINUTES = 60 * 5 // in seconds
  const timestamp = Date.now() / 1000
  const linkMetadata = metadata.value.links[linkIdx]

  // Iterate backwards until you reach older timestamps or find the same
  // recipient with a timestamp newer than five minutes
  for (const click of linkMetadata.click_data.slice().reverse()) {
    if (timestamp - click.timestamp > FIVE_MINUTES) {
      break
    }
    if (click.recipient === recipient) {
      return
    }
  }

  linkMetadata.click_count += 1
  linkMetadata.click_data.append({
    timestamp: timestamp,
    recipient: recipient,
  })
  metadata.save()
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/link/{accountId}/{messageId}/{linkIdx}`,
    config: {
      description: `link-tracking`,
      notes: 'Notes go here',
      tags: ['link-tracking'],
      auth: false,
      validate: {
        params: {
          accountId: Joi.string().required(),
          messageId: Joi.string().required(),
          linkIdx: Joi.number().integer().required(),
        },
        query: {
          redirect: Joi.string().required(),
          r: Joi.string(),
        },
      },
    },
    handler: (request, reply) => {
      const {accountId, messageId, linkIdx} = request.params
      let {redirect} = request.query
      const {r} = request.query

      if (!redirect) {
        reply('').code(404)
      } else if (!redirect.startsWith('http://') && !redirect.startsWith('https://')) {
        redirect = `https://${redirect}`
      }
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
            updateMetadata(metadata, recipient, linkIdx)
          } finally {
            reply.redirect(redirect)
          }
        })
      })
    },
  })
}
