const Joi = require('joi');
const _ = require('underscore');
const google = require('googleapis');
const OAuth2 = google.auth.OAuth2;

const Serialization = require('../serialization');
const {
  IMAPConnection,
  DatabaseConnector,
  SyncPolicy,
} = require('nylas-core');

// TODO: Move these to config somehow / somewhere
const CLIENT_ID = '271342407743-nibas08fua1itr1utq9qjladbkv3esdm.apps.googleusercontent.com';
const CLIENT_SECRET = 'WhmxErj-ei6vJXLocNhBbfBF';
const REDIRECT_URL = 'http://localhost:5100/auth/gmail/oauthcallback';

const SCOPES = [
  'https://www.googleapis.com/auth/userinfo.email',  // email address
  'https://www.googleapis.com/auth/userinfo.profile',  // G+ profile
  'https://mail.google.com/',  // email
  'https://www.google.com/m8/feeds',  // contacts
  'https://www.googleapis.com/auth/calendar',  // calendar
];

const imapSmtpSettings = Joi.object().keys({
  imap_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
  imap_port: Joi.number().integer().required(),
  imap_username: Joi.string().required(),
  imap_password: Joi.string().required(),
  smtp_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
  smtp_port: Joi.number().integer().required(),
  smtp_username: Joi.string().required(),
  smtp_password: Joi.string().required(),
  ssl_required: Joi.boolean().required(),
}).required();

const exchangeSettings = Joi.object().keys({
  username: Joi.string().required(),
  password: Joi.string().required(),
  eas_server_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
}).required();

const buildAccountWith = ({name, email, settings, credentials}) => {
  return DatabaseConnector.forShared().then((db) => {
    const {AccountToken, Account} = db;

    const account = Account.build({
      name: name,
      emailAddress: email,
      syncPolicy: SyncPolicy.defaultPolicy(),
      connectionSettings: settings,
    })
    account.setCredentials(credentials);

    return account.save().then((saved) =>
      AccountToken.create({
        AccountId: saved.id,
      }).then((token) =>
        Promise.resolve({account: saved, token: token})
      )
    );
  });
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: {
      description: 'Authenticates a new account.',
      notes: 'Notes go here',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          client_id: Joi.string().required(),
        },
        payload: {
          email: Joi.string().email().required(),
          name: Joi.string().required(),
          provider: Joi.string().required(),
          settings: Joi.alternatives().try(imapSmtpSettings, exchangeSettings),
        },
      },
      response: {
        schema: Joi.alternatives().try(
          Serialization.jsonSchema('Account'),
          Serialization.jsonSchema('Error')
        ),
      },
    },
    handler: (request, reply) => {
      const dbStub = {};
      const connectionChecks = [];
      const {settings, email, provider, name} = request.payload;

      if (provider === 'imap') {
        connectionChecks.push(new IMAPConnection(dbStub, settings).connect())
      }

      Promise.all(connectionChecks).then(() => {
        return buildAccountWith({
          name,
          email,
          settings: _.pick(settings, [
            'imap_host', 'imap_port',
            'smtp_host', 'smtp_port',
            'ssl_required',
          ]),
          credentials: _.pick(settings, [
            'imap_username', 'imap_password',
            'smtp_username', 'smtp_password',
          ]),
        })
      })
      .then(({account, token}) => {
        const response = account.toJSON();
        response.token = token.value;
        reply(Serialization.jsonStringify(response));
      })
      .catch((err) => {
        // TODO: Lots more of this
        console.log(err)
        reply({error: err.toString()});
      })
    },
  });

  server.route({
    method: 'GET',
    path: '/auth/gmail',
    config: {
      description: 'Redirects to Gmail OAuth',
      notes: 'Notes go here',
      tags: ['accounts'],
      auth: false,
    },
    handler: (request, reply) => {
      const oauthClient = new OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URL);
      reply.redirect(oauthClient.generateAuthUrl({
        access_type: 'offline',
        prompt: 'consent',
        scope: SCOPES,
      }));
    },
  });

  server.route({
    method: 'GET',
    path: '/auth/gmail/oauthcallback',
    config: {
      description: 'Authenticates a new account.',
      notes: 'Notes go here',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          code: Joi.string().required(),
        },
      },
    },
    handler: (request, reply) => {
      const oauthClient = new OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URL);
      oauthClient.getToken(request.query.code, (err, tokens) => {
        if (err) {
          reply(err.message).code(400);
          return;
        }
        oauthClient.setCredentials(tokens);
        google.oauth2({version: 'v2', auth: oauthClient}).userinfo.get((error, profile) => {
          if (error) {
            reply(error.message).code(400);
            return;
          }

          const settings = {
            imap_username: profile.email,
            imap_host: 'imap.gmail.com',
            imap_port: 993,
            ssl_required: true,
          }
          const credentials = {
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            client_id: CLIENT_ID,
            client_secret: CLIENT_SECRET,
          }

          Promise.all([
            new IMAPConnection({}, Object.assign({}, settings, credentials)).connect(),
          ])
          .then(() =>
            buildAccountWith({name: profile.name, email: profile.email, settings, credentials})
          )
          .then(({account, token}) => {
            const response = account.toJSON();
            response.token = token.value;
            reply(Serialization.jsonStringify(response));
          })
          .catch((connectionErr) => {
            // TODO: Lots more of this
            reply({error: connectionErr.toString()});
          });
        });
      });
    },
  });
}
