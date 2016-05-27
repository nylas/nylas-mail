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
    } else {
      this.APIRoot = "https://n1-auth.nylas.com";
    }
  }

  makeRequest(options = {}) {
    if (NylasEnv.getLoadSettings().isSpec) {
      return Promise.resolve();
    }

    options.auth = options.auth || {
      user: '',
      pass: '',
      sendImmediately: true,
    };

    const req = new NylasAPIRequest(this, options);
    return req.run();
  }
}

export default new EdgehillAPI;
