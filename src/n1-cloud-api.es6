import NylasAPIRequest from './flux/nylas-api-request';
import IdentityStore from './flux/stores/identity-store'

class N1CloudAPI {
  constructor() {
    NylasEnv.config.onDidChange('env', this._onConfigChanged);
    this._onConfigChanged();
  }

  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://localhost:5100";
    } else {
      this.APIRoot = "https://n1.nylas.com";
    }
  }

  makeRequest(options = {}) {
    if (NylasEnv.getLoadSettings().isSpec) return Promise.resolve();

    options.auth = options.auth || {
      user: IdentityStore.identityId(),
      pass: '',
    }

    const req = new NylasAPIRequest(this, options);
    return req.run();
  }
}

export default new N1CloudAPI();
