import AccountStore from './stores/account-store'
import IdentityStore from './stores/identity-store'
import NylasAPIRequest from './nylas-api-request';

// We're currently moving between services hosted on edgehill-api (written in
// Python) and services written in Node. Since we're doing this move progressively,
// we need to be able to use the two services at once. That's why we have two
// objects, EdgehillAPI (new API) and LegacyEdgehillAPI (old API).
class _EdgehillAPI {
  constructor() {
    NylasEnv.config.onDidChange('env', this._onConfigChanged);
    this._onConfigChanged();
  }

  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://n1-auth.lvh.me:5555";
    } else if (env === 'experimental') {
      this.APIRoot = "https://edgehill-experimental.nylas.com";
    } else if (env === 'staging') {
      this.APIRoot = "https://n1-auth-staging.nylas.com";
    } else {
      this.APIRoot = "https://n1-auth.nylas.com";
    }
  }

  accessTokenForAccountId(aid) {
    return AccountStore.tokensForAccountId(aid).n1Cloud
  }

  makeRequest(options = {}) {
    if (NylasEnv.getLoadSettings().isSpec) {
      return {run: () => Promise.resolve()}
    }

    if (options.authWithNylasAPI) {
      if (!IdentityStore.identity()) {
        throw new Error('LegacyEdgehillAPI.makeRequest: Identity must be present to make a request that auths with Nylas API')
      }
      // The account doesn't matter for Edgehill server. We just need to
      // ensure it's a valid account.
      options.accountId = AccountStore.accounts()[0].id;
      // The `NylasAPIRequest` object will grab the appropriate tokens.
      delete options.auth;
      delete options.authWithNylasAPI;
    } else {
      // A majority of Edgehill-server (aka auth) requests neither need
      // (nor have) account or N1 ID tokens to provide.
      // The existence of the options.auth object will prevent
      // `NylasAPIRequest` from constructing them from existing tokens
      options.auth = options.auth || {
        user: '',
        pass: '',
        sendImmediately: true,
      };
    }

    const req = new NylasAPIRequest({
      api: this,
      options,
    });
    return req;
  }
}

const EdgehillAPI = new _EdgehillAPI();
export {EdgehillAPI, _EdgehillAPI};
