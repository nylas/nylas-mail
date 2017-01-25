const Joi = require('joi')
const Base64 = require('js-base64').Base64
const Path = require('path')
const {DatabaseConnector} = require('cloud-core')

const PLUGIN_NAME = 'open-tracking'

function updateMetadata({metadata, recipient}) {
  if (!metadata) {
    throw new Error("No metadata found, unable to update.")
  }

  const FIVE_MINUTES = 60 * 5 // in seconds
  const timestamp = Date.now() / 1000

  if (!metadata.value || !metadata.value.open_data) {
    metadata.value = {
      open_count: 0,
      open_data: [],
    }
  }

  // Iterate backwards until you reach older timestamps or find the same
  // recipient with a timestamp newer than five minutes
  for (const open of metadata.value.open_data.slice().reverse()) {
    if (timestamp - open.timestamp > FIVE_MINUTES) {
      break
    }
    if (open.recipient === recipient) {
      return Promise.resolve()
    }
  }

  return metadata.updateValue({
    open_count: metadata.value.open_count + 1,
    open_data: metadata.value.open_data.concat({
      timestamp: timestamp,
      recipient: recipient,
    }),
  })
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/open/{messageId}`,
    config: {
      description: `open-tracking`,
      notes: 'Notes go here',
      tags: ['open-tracking'],
      auth: false,
      validate: {
        params: {
          messageId: Joi.string().required(),
        },
        query: {
          r: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      const {messageId} = request.params
      const {r} = request.query
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
        await updateMetadata({metadata, recipient})
      } catch (err) {
        request.logger.error(err, 'Error tracking open')
      } finally {
        reply.file(Path.join(__dirname, '../../static/images/transparent.gif'), {
          confine: false,
        })
        .header('Cache-Control', 'no-cache max-age=0')
      }
    },
  })
}
