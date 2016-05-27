import React from 'react';
import {isValidHost} from './onboarding-helpers';
import CreatePageForForm from './decorators/create-page-for-form';
import FormField from './form-field';

class AccountIMAPSettingsForm extends React.Component {
  static displayName = 'AccountIMAPSettingsForm';

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
    return 'Setup your account';
  }

  static subtitleLabel = () => {
    return 'Complete the IMAP and SMTP settings below to connect your account.';
  }

  static validateAccountInfo = (accountInfo) => {
    let errorMessage = null;
    const errorFieldNames = [];

    for (const type of ['imap', 'smtp']) {
      if (!accountInfo[`${type}_host`] || !accountInfo[`${type}_username`] || !accountInfo[`${type}_password`]) {
        return {errorMessage, errorFieldNames, populated: false};
      }
      if (!isValidHost(accountInfo[`${type}_host`])) {
        errorMessage = "Please provide a valid hostname or IP adddress.";
        errorFieldNames.push(`${type}_host`);
      }
      if (accountInfo[`${type}_host`] === 'imap.gmail.com') {
        errorMessage = "Please link Gmail accounts by choosing 'Google' on the account type screen.";
        errorFieldNames.push(`${type}_host`);
      }
      if (!Number.isInteger(accountInfo[`${type}_port`] / 1)) {
        errorMessage = "Please provide a valid port number.";
        errorFieldNames.push(`${type}_port`);
      }
    }

    return {errorMessage, errorFieldNames, populated: true};
  }

  submit() {
    this.props.onConnect();
  }

  renderFieldsForType(type) {
    const {accountInfo, errorFieldNames, submitting, onFieldKeyPress, onFieldChange} = this.props;

    return (
      <div>
        <FormField field={`${type}_host`} title={"Server"} {...this.props} />
        <div style={{textAlign: 'left'}}>
          <FormField field={`${type}_port`} title={"Port"} style={{width: 100, marginRight: 20}} {...this.props} />
          <input
            type="checkbox"
            id={`ssl_required`}
            className={(accountInfo.imap_host && errorFieldNames.includes(`ssl_required`)) ? 'error' : ''}
            disabled={submitting}
            checked={accountInfo[`ssl_required`] || false}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          />
          <label forHtml={`ssl_required`} className="checkbox">Require SSL</label>
        </div>
        <FormField field={`${type}_username`} title={"Username"} {...this.props} />
        <FormField field={`${type}_password`} title={"Password"} type="password" {...this.props} />
      </div>
    );
  }

  render() {
    return (
      <div className="twocol">
        <div className="col">
          <div className="col-heading">Incoming Mail (IMAP):</div>
          {this.renderFieldsForType('imap')}
        </div>
        <div className="col">
          <div className="col-heading">Outgoing Mail (SMTP):</div>
          {this.renderFieldsForType('smtp')}
        </div>
      </div>
    )
  }
}

export default CreatePageForForm(AccountIMAPSettingsForm);
