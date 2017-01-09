// We use this class to access all the services we haven't migrated
// yet to the new codebase.
import {_EdgehillAPI} from './edgehill-api'

class LegacyEdgehillAPI extends _EdgehillAPI {
  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://localhost:5009";
    } else if (env === 'experimental') {
      this.APIRoot = "https://edgehill-experimental.nylas.com";
    } else if (env === 'staging') {
      this.APIRoot = "https://edgehill-staging.nylas.com";
    } else {
      this.APIRoot = "https://edgehill.nylas.com";
    }
  }
}

export default new LegacyEdgehillAPI();
