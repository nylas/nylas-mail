import request from 'request-promise';
import {DatabaseConnector} from 'cloud-core';

let db = null // cache this.

/**
 * This is the validateFunc for https://github.com/hapijs/hapi-auth-basic
 *
 * API requests are of the form:
 * https://username:pass@n1.nylas.com/some/route
 *
 * The username field is the AccountToken of the N1 Cloud Account (aka
 * email account)
 * The password field is the N1 Identity Token.
 *
 * Then cb callback param must be called with the signature of:
 * function(err, isValid, credentials)
 */
export async function apiAuthenticate(req, username, password, cb) {
  const accountToken = username
  const n1IdentityToken = password
  if (!db) { db = await DatabaseConnector.forShared() }

  const token = await db.AccountToken.find({where: {value: accountToken}})
  if (!token) return cb(null, false, {});

  const account = await token.getAccount();
  account.n1IdentityToken = n1IdentityToken;
  req.logger = req.logger.forAccount(account);

  let identPath = "https://billing.nylas.com";
  if (process.env.NODE_ENV === "staging") {
    identPath = "https://billing-staging.nylas.com"
  } else if (process.env.NODE_ENV === "development") {
    identPath = "http://billing.lvh.me:5555"
  }

  identPath = "https://billing-staging.nylas.com"

  try {
    const identity = await request(`${identPath}/n1/user`, {
      auth: {username: n1IdentityToken, password: ''},
    })
    // req.logger.debug({identity}, `Got ${identPath} identity response`)
    return cb(null, true, {account, identity});
  } catch (err) {
    let statusCode = err;
    let responseBody = err;
    if (err && err.response) {
      statusCode = err.response.statusCode
      try {
        responseBody = JSON.parse(err.response.body);
      } catch (e) {
        responseBody = err.response.body;
      }
    }
    const responseDetails = {
      status_code: statusCode,
      body: responseBody,
    }

    let identityReqUri = "";
    if (err & err.options) {
      identityReqUri = err.options.uri
    }

    // cannot log entire err object because it contains sensitive information
    // such as the account token & auth headers - see example below
    req.logger.error({
      error_name: err.name,
      identity_req_uri: identityReqUri,
      response_details: responseDetails,
    }, `Invalid credentials, can't authenticate`)
    return cb(null, false, {})
  }
}

// Example `error` object querying identity server (from above):
//
// {
//     "error": "{\n  \"message\": \"Invalid credentials.\",\n  \"type\": \"invalid_request_error\"\n}",
//     "message": "400 - \"{\\n  \\\"message\\\": \\\"Invalid credentials.\\\",\\n  \\\"type\\\": \\\"invalid_request_error\\\"\\n}\"",
//     "name": "StatusCodeError",
//     "options": {
//         "auth": {
//             "pass": "",
//             "password": "",
//             "user": "KQPTpmOsPeTneqFAcNh9dbvU4OGZSd",
//             "username": "KQPTpmOsPeTneqFAcNh9dbvU4OGZSd"
//         },
//         "resolveWithFullResponse": false,
//         "simple": true,
//         "transform2xxOnly": false,
//         "uri": "https://billing-staging.nylas.com/n1/user"
//     },
//     "response": {
//         "body": " {\n  \"message\": \"Invalid credentials.\",\n  \"type\": \"invalid_request_error\"\n}",
//         "headers": {
//             "connection": "close",
//             "content-length": "74",
//             "content-type": "application/json",
//             "date": "Fri, 03 Feb 2017 22:19:44 GMT",
//             "server": "nginx/1.6.2",
//             "strict-transport-security": "max-age=31536000;",
//             "x-frame-options": "SAMEORIGIN, SAMEORIGIN"
//         },
//         "request": {
//             "headers": {
//                 "authorization": "Basic S1FQVHBtT3NQZVRuZXFGQWNOaDlkYnZVNE9HWlNkOg=="
//             },
//             "method": "GET",
//             "uri": {
//                 "auth": null,
//                 "hash": null,
//                 "host": "billing-staging.nylas.com",
//                 "hostname": "billing-staging.nylas.com",
//                 "href": "https://billing-staging.nylas.com/n1/user",
//                 "path": "/n1/user",
//                 "pathname": "/n1/user",
//                 "port": 443,
//                 "protocol": "https:",
//                 "query": null,
//                 "search": null,
//                 "slashes": true
//             }
//         },
//         "statusCode": 400
//     },
//     "statusCode": 400
// }
