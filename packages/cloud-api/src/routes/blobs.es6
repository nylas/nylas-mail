const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

const NODE_ENV = process.env.NODE_ENV || 'production'
const BUCKET_NAME = process.env.BUCKET_NAME
const AWS_ACCESS_KEY_ID = process.env.BUCKET_AWS_ACCESS_KEY_ID
const AWS_SECRET_ACCESS_KEY = process.env.BUCKET_AWS_SECRET_ACCESS_KEY

if (NODE_ENV !== 'development' &&
  (!BUCKET_NAME || !AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY)) {
  throw new Error("You need to define S3 access credentials.")
}

AWS.config.update({
  accessKeyId: AWS_ACCESS_KEY_ID,
  secretAccessKey: AWS_SECRET_ACCESS_KEY })

async function localUpload(account, data, reply) {
  const uploadId = `${account.id}-${data.id}`;
  const filepath = path.join("/", "tmp", "uploads", uploadId);
  const file = fs.createWriteStream(filepath, { flags: 'w+' });

  file.on('error', (err) => {
    console.error(err)
  });

  data.file.pipe(file);

  data.file.on('end', (err) => {
    if (err) {
      reply({error: err.toString()}).code(409);
    }

    const ret = {
      filename: data.file.hapi.filename,
    }
    reply(JSON.stringify(ret));
  })
}

async function s3Upload(account, data, reply) {
  const uploadId = `${account.id}-${data.id}`;
  const s3 = new AWS.S3({apiVersion: '2006-03-01'});

  // This is amazing. The AWS S3 SDK won't take a stream as an input. Hapi gives
  // us a stream, but behind the scenes it's backed by a buffer holding the whole
  // thing in memory. We just cut the middleman and give the S3 SDK what it
  // wants.
  const uploadedData = data.file._data;
  s3.putObject({
    Bucket: BUCKET_NAME,
    Key: uploadId,
    Body: uploadedData,
  }, (err, response) => {
    if (err) {
      reply({type: "error", message: "Couldn't upload data to S3"}).code(500);
    } else {
      const ret = {
        filename: data.file.hapi.filename,
      }
      reply(JSON.stringify(ret));
    }
  })

  reply({filename: data.file.hapi.filename})
}

module.exports = (server) => {
  const ONE_MEG = 1048576;
  const MAX_ATTACHMENT_SIZE = 25 * ONE_MEG;
  server.route({
    method: ['PUT', 'POST'],
    path: `/blobs`,
    config: {
      description: `Upload a draft attachment to S3.`,
      tags: ['drafts'],
      payload: {
        output: 'stream',
        parse: true,
        maxBytes: MAX_ATTACHMENT_SIZE, // Limit upload size to 25 Megs.
        allow: 'multipart/form-data',
      },
    },
    handler: async (request, reply) => {
      const data = request.payload;
      const {account} = request.auth.credentials;

      if (!data.id || !data.file) {
        reply({error: `You need to supply a file and an id`}).code(400);
      }

      if (NODE_ENV === 'development') {
        localUpload(account, data, reply);
      } else {
        s3Upload(account, data, reply);
      }
    },
  });
};
