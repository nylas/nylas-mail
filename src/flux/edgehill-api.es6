import AccountStore from './stores/account-store'
import NylasAPIRequest from './nylas-api-request';

class EdgehillAPI {
  constructor() {
    NylasEnv.config.onDidChange('env', this._onConfigChanged);
    this._onConfigChanged();
  }

  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://localhost:5009";
    } else if (env === 'experimental') {
      this.APIRoot = "https://edgehill-experimental.nylas.com";
    } else if (env === 'staging') {
      this.APIRoot = "https://n1-auth-staging.nylas.com";
    } else if (env === 'k2') {
      this.APIRoot = "http://localhost:5100";
    } else {
      this.APIRoot = "https://n1-auth.nylas.com";
    }
  }

  accessTokenForAccountId(aid) {
    return AccountStore.tokenForAccountId(aid)
  }

  makeRequest(options = {}) {
    if (NylasEnv.getLoadSettings().isSpec) {
      return Promise.resolve();
    }

    if (options.authWithNylasAPI) {
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

    const req = new NylasAPIRequest(this, options);
    return req.run();
  }
}

export default new EdgehillAPI();
