const Joi = require('joi');
const nodemailer = require('nodemailer');
const {DatabaseConnector} = require('nylas-core');

function toParticipant(payload) {
  return payload.map((p) => `${p.name} <${p.email}>`).join(',')
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/send',
    config: {
      validate: {
        payload: {
          subject: Joi.string(),
          reply_to_message_id: Joi.number().integer(),
          from: Joi.array(),
          reply_to: Joi.array(),
          to: Joi.array(),
          cc: Joi.array(),
          bcc: Joi.array(),
          body: Joi.string(),
          file_ids: Joi.array(),
        },
      },
    },
    handler: (request, reply) => { DatabaseConnector.forShared().then((db) => {
      const accountId = request.auth.credentials.id;
      db.Account.findById(accountId).then((account) => {
        const sender = nodemailer.createTransport(account.smtpConfig());
        const data = request.payload;

        const msg = {}
        for (key of ['from', 'to', 'cc', 'bcc']) {
          if (data[key]) msg[key] = toParticipant(data[key])
        }
        msg.subject = data.subject,
        msg.html = data.body,

        console.log("------------------------------------------------")
        console.log(msg)
        sender.sendMail(msg, (error, info) => {
          console.log("DONE ===========================================");
          console.log(error)
          console.log(info)
          if (error) { reply(error).code(400) }
          else { reply(info.response) }
        });
      })
    })},
  });
};
