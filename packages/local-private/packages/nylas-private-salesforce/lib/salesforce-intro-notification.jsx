import React from 'react'
import {shell} from 'electron'

import {Notification} from 'nylas-component-kit'
import SalesforceEnv from './salesforce-env'
import {INFO_DOC_URL} from './salesforce-constants'
import SalesforceActions from './salesforce-actions'

export default class SalesforceIntroNotification extends React.Component {

  static displayName = "SalesforceIntroNotification"
  static containerRequired = false

  constructor(props) {
    super(props)
    this.state = {
      isLoggedIn: SalesforceEnv.isLoggedIn(),
    }
  }

  componentDidMount() {
    this._unsub = SalesforceEnv.listen(this._onLoginStateChanged)
  }

  componentWillUnmount() {
    this._unsub()
  }

  _onLoginStateChanged = () => {
    this.setState({isLoggedIn: SalesforceEnv.isLoggedIn()})
  }

  render() {
    let actions = [{
      label: "Connect Salesforce",
      fn: () => {
        SalesforceActions.loginToSalesforce()
      },
    }]

    if (this.state.isLoggedIn) {
      actions = [{
        label: "Learn More",
        fn: () => {
          shell.openExternal(INFO_DOC_URL)
        },
      }]
    }

    return (
      <Notification
        priority="1"
        displayName={SalesforceIntroNotification.displayName}
        title="Welcome to the Nylas Salesforce trial!"
        actions={actions}
        isDismissable
        isPermanentlyDismissable
      />
    )
  }
}
