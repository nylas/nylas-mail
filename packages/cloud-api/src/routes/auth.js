const Joi = require('joi');
const google = require('googleapis');
const OAuth2 = google.auth.OAuth2;

const {DatabaseConnector} = require('cloud-core');
const Serialization = require('../serialization');

const {
  Provider,
  AuthHelpers,
  IMAPConnection,
} = require('isomorphic-core');

const {GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL} = process.env;

const SCOPES = [
  'https://www.googleapis.com/auth/userinfo.email',  // email address
  'https://www.googleapis.com/auth/userinfo.profile',  // G+ profile
  'https://mail.google.com/',  // email
  'https://www.google.com/m8/feeds',  // contacts
  'https://www.googleapis.com/auth/calendar',  // calendar
];

const accountBuildFn = (accountParams, credentials) => {
  return DatabaseConnector.forShared().then(({Account}) =>
    Account.upsertWithCredentials(accountParams, credentials)
  );
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: AuthHelpers.imapAuthRouteConfig(),
    handler: AuthHelpers.imapAuthHandler(accountBuildFn),
  });

  server.route({
    method: 'GET',
    path: '/auth/gmail',
    config: {
      description: 'Redirects to Gmail OAuth',
      notes: 'Notes go here',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          state: Joi.string().default('none'),
        },
      },
    },
    handler: (request, reply) => {
      const oauthClient = new OAuth2(GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL);
      reply.redirect(oauthClient.generateAuthUrl({
        access_type: 'offline',
        prompt: 'consent',
        scope: SCOPES,
        state: request.query.state,
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
          state: Joi.string().required(),
          code: Joi.string().required(),
        },
      },
    },

    handler: (request, reply) => {
      const oauthClient = new OAuth2(GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL);
      oauthClient.getToken(request.query.code, (err, tokens) => {
        if (err) {
          reply({message: err.message, type: "api_error", step: 'get-token'}).code(400);
          return;
        }
        oauthClient.setCredentials(tokens);
        google.oauth2({version: 'v2', auth: oauthClient}).userinfo.get((error, profile) => {
          if (error) {
            reply({message: error.message, type: "api_error", step: 'get-profile'}).code(400);
            return;
          }

          const settings = {
            imap_username: profile.email,
            imap_host: 'imap.gmail.com',
            imap_port: 993,
            ssl_required: true,
          }
          const credentials = {
            refresh_token: tokens.refresh_token,
            client_id: GMAIL_CLIENT_ID,
            client_secret: GMAIL_CLIENT_SECRET,
          }
          Promise.all([
            IMAPConnection.connect({
              logger: request.logger,
              settings: Object.assign({}, settings, credentials),
              db: {},
            }),
          ])
          .then((conns) => {
            const imap = conns[0];
            if (imap) { imap.end(); }

            return DatabaseConnector.forShared().then((db) => {
              const accountParams = {
                name: profile.name,
                provider: Provider.Gmail,
                emailAddress: profile.email,
                connectionSettings: settings,
              }
              return accountBuildFn(accountParams, credentials)
              .then(({account, token}) => {
                const response = account.toJSON();
                response.account_token = token.value;
                response.resolved_settings = imap.resolvedSettings;
                return db.PendingAuthResponse.create({
                  response: Serialization.jsonStringify(response),
                  pendingAuthKey: request.query.state,
                })
              })
              .then(() => {
                return reply("Thanks! Go back to N1 now.");
              })
              .catch((connectionErr) => {
                return reply({message: connectionErr.message, type: "api_error"}).code(400);
              });
            });
          });
        });
      });
    },
  });

  server.route({
    method: "GET",
    path: "/auth/gmail/token",
    config: {
      auth: false,
      validate: {
        query: {
          key: Joi.string().required(),
        },
      },
    },
    handler: (req, res) => {
      DatabaseConnector.forShared().then(({PendingAuthResponse}) => {
        PendingAuthResponse.find({where: {pendingAuthKey: req.query.key}}).then((pending) => {
          if (pending) {
            res(pending.response).code(200);
            pending.destroy();
          } else {
            res({error: "Not found."}).code(404);
          }
        })
        .catch((err) => {
          return res(err).code(404);
        });
      });
    },
  })
}
