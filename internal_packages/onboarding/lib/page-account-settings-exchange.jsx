import React from 'react';
import {RegExpUtils} from 'nylas-exports';
import {isValidHost} from './onboarding-helpers';
import CreatePageForForm from './decorators/create-page-for-form';
import FormField from './form-field';

class AccountExchangeSettingsForm extends React.Component {
  static displayName = 'AccountExchangeSettingsForm';

  static propTypes = {
    accountInfo: React.PropTypes.object,
    errorFieldNames: React.PropTypes.array,
    submitting: React.PropTypes.bool,
    onConnect: React.PropTypes.func,
    onFieldChange: React.PropTypes.func,
    onFieldKeyPress: React.PropTypes.func,
  };

  static submitLabel = () => {
    return 'Connect Account';
  }

  static titleLabel = () => {
    return 'Add your Exchange account';
  }

  static subtitleLabel = () => {
    return 'Enter your Exchange credentials to get started.';
  }

  static validateAccountInfo = (accountInfo) => {
    const {email, password, name} = accountInfo;
    const errorFieldNames = [];
    let errorMessage = null;

    if (!email || !password || !name) {
      return {errorMessage, errorFieldNames, populated: false};
    }

    if (!RegExpUtils.emailRegex().test(accountInfo.email)) {
      errorFieldNames.push('email')
      errorMessage = "Please provide a valid email address."
    }
    if (!accountInfo.password) {
      errorFieldNames.push('password')
      errorMessage = "Please provide a password for your account."
    }
    if (!accountInfo.name) {
      errorFieldNames.push('name')
      errorMessage = "Please provide your name."
    }
    if (accountInfo.eas_server_host && !isValidHost(accountInfo.eas_server_host)) {
      errorFieldNames.push('eas_server_host')
      errorMessage = "Please provide a valid host name."
    }

    return {errorMessage, errorFieldNames, populated: true};
  }

  constructor(props) {
    super(props);
    this.state = {showAdvanced: false};
  }

  submit() {
    this.props.onConnect();
  }

  render() {
    const {errorFieldNames, accountInfo} = this.props;
    const showAdvanced = (
      this.state.showAdvanced ||
      errorFieldNames.includes('eas_server_host') ||
      errorFieldNames.includes('username') ||
      accountInfo.eas_server_host ||
      accountInfo.username
    );

    let classnames = "twocol";
    if (!showAdvanced) {
      classnames += " hide-second-column";
    }

    return (
      <div className={classnames}>
        <div className="col">
          <FormField field="name" title="Name" {...this.props} />
          <FormField field="email" title="Email" {...this.props} />
          <FormField field="password" title="Password" type="password" {...this.props} />
          <a className="toggle-advanced" onClick={() => this.setState({showAdvanced: !this.state.showAdvanced})}>
            {showAdvanced ? "Hide Advanced Options" : "Show Advanced Options"}
          </a>
        </div>
        <div className="col">
          <FormField field="username" title="Username (Optional)" {...this.props} />
          <FormField field="eas_server_host" title="Exchange Server (Optional)" {...this.props} />
        </div>
      </div>
    )
  }
}

export default CreatePageForForm(AccountExchangeSettingsForm);
