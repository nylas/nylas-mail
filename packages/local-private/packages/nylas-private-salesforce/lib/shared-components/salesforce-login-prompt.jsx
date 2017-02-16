import React from 'react'
import {shell} from 'electron'
import {RetinaImg} from 'nylas-component-kit'

import {INFO_DOC_URL} from '../salesforce-constants'
import SalesforceActions from '../salesforce-actions'


class SalesforceLoginPrompt extends React.Component {
  static displayName = "SalesforceLoginPrompt"

  _connectSalesforce() {
    SalesforceActions.loginToSalesforce()
  }

  render() {
    const onClick = () => shell.openExternal(INFO_DOC_URL)
    return (
      <div className="salesforce-login salesforce">
        <div onClick={this._connectSalesforce} className="salesforce-no-connect-placeholder">
          <RetinaImg
            url="nylas://nylas-private-salesforce/static/images/salesforce-logo@2x.png"
            className="salesforce-empty-img"
            mode={RetinaImg.Mode.ContentDark}
          />
        </div>
        <div className="salesforce-prompt">
          <button className="btn" onClick={this._connectSalesforce}>Connect Salesforce</button>
          <p><a onClick={onClick}>Learn More</a></p>
        </div>
      </div>
    )
  }
}

export default SalesforceLoginPrompt
