const Joi = require('joi')
const Base64 = require('js-base64').Base64
const {DatabaseConnector} = require('cloud-core')

const PLUGIN_NAME = 'link-tracking'

function updateMetadata({metadata, recipient, linkIdx}) {
  if (!metadata) {
    throw new Error("No metadata found, unable to update.")
  }

  const FIVE_MINUTES = 60 * 5 // in seconds
  const timestamp = Date.now() / 1000

  if (!metadata.value || !metadata.value.links) {
    throw new Error('Message metadata does not have links to track!')
  }
  const linkMetadata = metadata.value.links[linkIdx]

  // Iterate backwards until you reach older timestamps or find the same
  // recipient with a timestamp newer than five minutes
  for (const click of linkMetadata.click_data.slice().reverse()) {
    if (timestamp - click.timestamp > FIVE_MINUTES) {
      break
    }
    if (click.recipient === recipient) {
      return Promise.resolve()
    }
  }

  const links = metadata.value.links
  links[linkIdx] = {
    url: linkMetadata.url,
    click_count: linkMetadata.click_count + 1,
    click_data: linkMetadata.click_data.concat({
      timestamp: timestamp,
      recipient: recipient,
    }),
    redirect_url: linkMetadata.url,
  }
  return metadata.updateValue({links})
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/link/{messageId}/{linkIdx}`,
    config: {
      description: `link-tracking`,
      notes: 'Notes go here',
      tags: ['link-tracking'],
      auth: false,
      validate: {
        params: {
          messageId: Joi.string().required(),
          linkIdx: Joi.number().integer().required(),
        },
        query: {
          redirect: Joi.string().required(),
          r: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      const {messageId, linkIdx} = request.params
      let {redirect} = request.query
      const {r} = request.query

      if (!redirect) {
        reply('').code(404)
      } else if (!redirect.startsWith('http://') && !redirect.startsWith('https://')) {
        redirect = `https://${redirect}`
      }
      const recipient = r ? Base64.decode(r) : null

      const {Metadata} = await DatabaseConnector.forShared()
      const metadata = await Metadata.find({
        where: {
          pluginId: PLUGIN_NAME,
          objectId: messageId,
          objectType: 'message',
        },
      })
      try {
        await updateMetadata({metadata, recipient, linkIdx})
      } catch (err) {
        request.logger.error(err, 'Error tracking link')
      } finally {
        reply.redirect(redirect)
      }
    },
  })
}
