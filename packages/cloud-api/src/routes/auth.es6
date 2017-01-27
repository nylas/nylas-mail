import Joi from 'joi';
import Boom from 'boom';
import google from 'googleapis';
import {DatabaseConnector} from 'cloud-core';
import GAuth from '../gmail-oauth-helpers'
const {GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL} = process.env;

const OAuth2 = google.auth.OAuth2;

const {
  AuthHelpers,
  IMAPConnection,
  IMAPErrors,
} = require('isomorphic-core');

const SCOPES = [
  'https://www.googleapis.com/auth/userinfo.email',  // email address
  'https://www.googleapis.com/auth/userinfo.profile',  // G+ profile
  'https://mail.google.com/',  // email
  'https://www.google.com/m8/feeds',  // contacts
  'https://www.googleapis.com/auth/calendar',  // calendar
];

const upsertAccount = (accountParams, credentials) => {
  return DatabaseConnector.forShared().then(({Account}) =>
    Account.upsertWithCredentials(accountParams, credentials)
  );
}

/**
 * How Gmail Auth works:
 *
 * 0. The N1 AccountSettingsPageGmail, upon mounting, (via the
 * OAuthSignInPage) opens in the user's default browser a link to
 * GET /auth/gmail?state=SOME_KEY. We use the default browser because
 * people are likely already signed in there.
 *
 * 1. the /auth/gmail route uses our Nylas Gmail Client Secret (which is
 * why we have to do Gmail auth in N1 cloud) and redirects the user to the
 * Google account sign in page where they enter their credentials and 2FA
 * (if they have any).
 *
 * 2. Upon successful auth, Gmail redirects back to GMAIL_REDIRECT_URL,
 * which is set to /auth/gmail/oauthcallback. Here we exchange the code
 * we're given for a Google OAuth token. We also access the user's Google
 * profile to extract their name and email. We finally use those
 * connection settings to log into Google via IMAP. We then create an
 * Account object on N1 Cloud and create an N1 Cloud Account token that n1
 * can use to access the account object (and credentials) on N1 Cloud.
 * Once successful we create a `PendingAuthResponse` which will allow N1
 * to access the credentials via a one-use key that it set in the OAuth
 * State parameter in step 0
 *
 * 3. N1 now polls /auth/gmail/token with the key use used in step 0. Once
 * the corresponding `PendingAuthResponse` shows up in our database, we
 * give the xoauth2 token and an N1 Cloud Account token back to N1.
 *
 * 4. The xoauth2 token that we give back to N1 only works for an hour.
 * Every hour or so N1 must request a new one via the /auth/gmail/refresh
 * endpoint. Using the N1 Cloud Account token, we can lookup the account,
 * get the original Google refresh token, then use that refresh token to
 * get a new xoauth2 token and return it to N1.
 */
export default function registerAuthRoutes(server) {
  server.route({
    method: 'POST',
    path: '/auth',
    config: AuthHelpers.imapAuthRouteConfig(),
    handler: AuthHelpers.imapAuthHandler(upsertAccount),
  });

  /**
   * Gmail Auth Step 1
   */
  server.route({
    method: 'GET',
    path: '/auth/gmail',
    config: {
      description: 'Redirects to Gmail OAuth',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          state: Joi.string().required(),
        },
      },
    },
    async handler(request, reply) {
      request.logger.info("Redirecting to Gmail OAuth")
      try {
        const oauthClient = GAuth.newOAuthClient();
        const authUrl = oauthClient.generateAuthUrl({
          access_type: 'offline',
          prompt: 'consent',
          scope: SCOPES,
          state: request.query.state,
        });
        reply.redirect(authUrl)
      } catch (err) {
        reply(Boom.wrap(err))
      }
    },
  });

  /**
   * Gmail Auth Step 2
   */
  server.route({
    method: 'GET',
    path: '/auth/gmail/oauthcallback',
    config: {
      description: 'Authenticates a new account.',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          state: Joi.string().required(),
          code: Joi.string(),
          error: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      request.logger.info('Have Google OAuth Code. Exchanging for token')
      const code = request.query.code
      const n1Key = request.query.state
      const error = request.query.error // Google sometimes passes the error back here
      let profile = {};
      let account = {};

      try {
        const client = GAuth.newOAuthClient()
        const tok = await GAuth.exchangeCodeForGoogleToken(client, code);

        profile = await GAuth.fetchGoogleProfile(client);
        const settings = GAuth.imapSettings(tok, profile)

        request.logger.info("Resolving IMAP connection")

        settings.resolved = await GAuth.resolveIMAPSettings(settings, request.logger)
        account = await GAuth.createCloudAccount(settings, profile)

        request.logger.info("Creating PendingAuthResponse")
        await GAuth.createPendingAuthResponse(account, settings, n1Key)
      } catch (err) {
        const res = {
          state_string: n1Key,
          google_client_id: GMAIL_CLIENT_ID,
          redirect_uri: GMAIL_REDIRECT_URL,
          error: err.message,
        }
        const logger = request.logger.child({
          account_provider: 'gmail',
          account_email: account.emailAddress || profile.email,
          error: err,
          error_message: err.message,
          error_source: err.source,
        })

        // TODO make sure we are considering all possible errors
        if (error === 'access_denied') {
          res.try_again = true
          res.access_denied = true
          logger.error('Encountered access denied error while exchanging gmail oauth code for token')
        } else if (err instanceof IMAPErrors.IMAPAuthenticationError) {
          res.try_again = true
          res.imap_auth_error = true
          logger.error('Encountered imap auth error while exchanging gmail oauth code for token')
        } else if (err instanceof IMAPErrors.IMAPAuthenticationTimeoutError || err instanceof IMAPErrors.IMAPConnectionTimeoutError) {
          res.try_again = true
          res.auth_timeout = true
          logger.error('Encountered imap timeout error while exchanging gmail oauth code for token')
        } else if ((err.message || '').includes("invalid_grant")) {
          res.try_again = true
          res.invalid_grant = true
          logger.error('Encountered invalid grant error while exchanging gmail oauth code for token')
        } else {
          logger.error('Encountered unknown error while exchanging gmail oauth code for token')
        }

        reply.view('gmail-auth-failure', res)
        return
      }

      reply.view('gmail-auth-success')
    },
  });

  /**
   * Gmail Auth Step 3
   * N1 continues to poll this endpoint with the original key it set in
   * the state parameter during Step 1
   */
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
    async handler(request, reply) {
      const {PendingAuthResponse} = await DatabaseConnector.forShared();
      let tokenData = null;
      try {
        tokenData = await PendingAuthResponse.find({where:
          {pendingAuthKey: request.query.key},
        })
        if (!tokenData) {
          return reply(Boom.notFound())
        }
      } catch (err) {
        return reply(Boom.notFound())
      }
      if (!tokenData.response) {
        request.logger.error("Error getting access token, malformed PendingAuthResponse")
        return reply(Boom.badImplementation("Malformed PendingAuthResponse", tokenData))
      }
      await tokenData.destroy()
      return reply(tokenData.response)
    },
  });

  server.route({
    method: "POST",
    path: "/auth/gmail/refresh",
    handler(request, reply) {
      const {account} = request.auth.credentials;
      const oauthClient = new OAuth2(GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REDIRECT_URL);
      const credentials = account.decryptedCredentials();
      oauthClient.setCredentials({ refresh_token: credentials.refresh_token });
      oauthClient.refreshAccessToken((err, tokens) => {
        if (err != null) {
          request.logger.error(err, 'Error refreshing gmail access token.');
          reply('Backend error: could not refresh Gmail access token. Please try again.').code(400);
          return
        }

        const res = {}
        res.access_token = tokens.access_token;
        res.xoauth2 = IMAPConnection.generateXOAuth2Token(account.emailAddress,
                                                          tokens.access_token);
        res.expiry_date = Math.floor(tokens.expiry_date / 1000);
        reply(res).code(200);
      });
    },
  });
}
