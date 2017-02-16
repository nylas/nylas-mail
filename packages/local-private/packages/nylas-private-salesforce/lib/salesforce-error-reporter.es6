import SalesforceEnv from './salesforce-env'
import SalesforceActions from './salesforce-actions'

class SalesforceErrorReporter {
  activate() {
    this._usub = SalesforceActions.reportError.listen(this._onError)
  }

  deactivate() {
    this._usub();
  }

  _onError = (error, extraInfo = {}) => {
    SalesforceEnv.loadIdentity().then((identity) => {
      NylasEnv.reportError(error, Object.assign({}, extraInfo, {
        identity: identity,
        instanceUrl: SalesforceEnv.instanceUrl(),
      }));
    })
  }
}
export default new SalesforceErrorReporter()
