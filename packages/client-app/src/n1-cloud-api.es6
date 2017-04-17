import {AccountStore} from 'nylas-exports'

class N1CloudAPI {
  constructor() {
    NylasEnv.config.onDidChange('env', this._onConfigChanged);
    this._onConfigChanged();
  }

  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://lvh.me:5100";
    } else if (env === 'staging') {
      this.APIRoot = "https://n1-staging.nylas.com";
    } else {
      this.APIRoot = "https://n1.nylas.com";
    }
  }

  accessTokenForAccountId = (aid) => {
    return AccountStore.tokensForAccountId(aid).n1Cloud
  }
}

export default new N1CloudAPI();
