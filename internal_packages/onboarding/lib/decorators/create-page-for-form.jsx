import {shell} from 'electron'
import React from 'react';
import ReactDOM from 'react-dom';
import {RetinaImg} from 'nylas-component-kit';
import {NylasAPI, Actions} from 'nylas-exports';

import OnboardingActions from '../onboarding-actions';
import {runAuthRequest} from '../onboarding-helpers';
import FormErrorMessage from '../form-error-message';
import AccountTypes from '../account-types'

const CreatePageForForm = (FormComponent) => {
  return class Composed extends React.Component {
    static displayName = FormComponent.displayName;

    static propTypes = {
      accountInfo: React.PropTypes.object,
    };

    constructor(props) {
      super(props);

      this.state = Object.assign({
        accountInfo: JSON.parse(JSON.stringify(this.props.accountInfo)),
        errorFieldNames: [],
        errorMessage: null,
      }, FormComponent.validateAccountInfo(this.props.accountInfo));
    }

    componentDidMount() {
      this._applyFocus();
    }

    componentDidUpdate() {
      this._applyFocus();
    }

    _applyFocus() {
      const anyInputFocused = document.activeElement && document.activeElement.nodeName === 'INPUT';
      if (anyInputFocused) {
        return;
      }

      const inputs = Array.from(ReactDOM.findDOMNode(this).querySelectorAll('input'));
      if (inputs.length === 0) {
        return;
      }

      for (const input of inputs) {
        if (input.value === '') {
          input.focus();
          return;
        }
      }
      inputs[0].focus();
    }

    onFieldChange = (event) => {
      const changes = {};
      if (event.target.type === 'checkbox') {
        changes[event.target.id] = event.target.checked;
      } else {
        changes[event.target.id] = event.target.value;
      }

      const accountInfo = Object.assign({}, this.state.accountInfo, changes);
      const {errorFieldNames, errorMessage, populated} = FormComponent.validateAccountInfo(accountInfo);

      this.setState({accountInfo, errorFieldNames, errorMessage, populated, errorStatusCode: null});
    }

    onSubmit = () => {
      OnboardingActions.setAccountInfo(this.state.accountInfo);
      this.refs.form.submit();
    }

    onFieldKeyPress = (event) => {
      if (['Enter', 'Return'].includes(event.key)) {
        this.onSubmit();
      }
    }

    onBack = () => {
      OnboardingActions.setAccountInfo(this.state.accountInfo);
      OnboardingActions.moveToPreviousPage();
    }

    onConnect = (updatedAccountInfo) => {
      const accountInfo = updatedAccountInfo || this.state.accountInfo;

      this.setState({submitting: true});

      runAuthRequest(accountInfo)
      .then((json) => {
        OnboardingActions.moveToPage('account-onboarding-success')
        OnboardingActions.accountJSONReceived(json, json.localToken, json.cloudToken)
      })
      .catch((err) => {
        Actions.recordUserEvent('Email Account Auth Failed', {
          errorMessage: err.message,
          provider: accountInfo.type,
        })

        const errorFieldNames = err.body ? (err.body.missing_fields || err.body.missing_settings || []) : []
        let errorMessage = err.message;
        const errorStatusCode = err.statusCode

        if (err.errorType === "setting_update_error") {
          errorMessage = 'The IMAP/SMTP servers for this account do not match our records. Please verify that any server names you entered are correct. If your IMAP/SMTP server has changed, first remove this account from Nylas Mail, then try logging in again.';
        }
        if (err.errorType && err.errorType.includes("autodiscover") && (accountInfo.type === 'exchange')) {
          errorFieldNames.push('eas_server_host')
          errorFieldNames.push('username');
        }
        if (err.statusCode === 401) {
          errorFieldNames.push('password')
          errorFieldNames.push('email');
          errorFieldNames.push('username');
          errorFieldNames.push('imap_username');
          errorFieldNames.push('smtp_username');
          errorFieldNames.push('imap_password');
          errorFieldNames.push('smtp_password');
        }
        if (NylasAPI.TimeoutErrorCodes.includes(err.statusCode)) { // timeout
          errorMessage = "We were unable to reach your mail provider. Please try again."
        }

        this.setState({errorMessage, errorStatusCode, errorFieldNames, submitting: false});
      });
    }

    _renderButton() {
      const {accountInfo, submitting, errorFieldNames, populated} = this.state;
      const buttonLabel = FormComponent.submitLabel(accountInfo);

      // We're not on the last page.
      if (submitting) {
        return (
          <button className="btn btn-large btn-disabled btn-add-account spinning">
            <RetinaImg name="sending-spinner.gif" width={15} height={15} mode={RetinaImg.Mode.ContentPreserve} />
            Adding account&hellip;
          </button>
        );
      }

      if (errorFieldNames.length || !populated) {
        return (
          <button className="btn btn-large btn-gradient btn-disabled btn-add-account">{buttonLabel}</button>
        );
      }

      return (
        <button className="btn btn-large btn-gradient btn-add-account" onClick={this.onSubmit}>{buttonLabel}</button>
      );
    }

    // When a user enters the wrong credentials, show a message that could
    // help with common problems. For instance, they may need an app password,
    // or to enable specific settings with their provider.
    _renderCredentialsNote() {
      const {errorStatusCode, accountInfo} = this.state;
      if (errorStatusCode !== 401) { return false; }
      let message;
      let articleURL;
      if (accountInfo.email.includes("@yahoo.com")) {
        message = "Have you enabled access through Yahoo?";
        articleURL = "https://support.nylas.com/hc/en-us/articles/115001076128";
      } else {
        message = "Some providers require an app password."
        articleURL = "https://support.nylas.com/hc/en-us/articles/115001056608";
      }
      // We don't use a FormErrorMessage component because the content
      // we need to display has HTML.
      return (
        <div className="message error">
          {message}&nbsp;
          <a
            href=""
            style={{cursor: 'pointer'}}
            onClick={() => { shell.openExternal(articleURL) }}
          >
            Learn more.
          </a>
        </div>
      );
    }

    render() {
      const {accountInfo, errorMessage, errorFieldNames, submitting} = this.state;
      const AccountType = AccountTypes.find(a => a.type === accountInfo.type);

      if (!AccountType) {
        throw new Error(`Cannot find account type ${accountInfo.type}`);
      }

      const hideTitle = errorMessage && errorMessage.length > 120;

      return (
        <div className={`page account-setup ${FormComponent.displayName}`}>
          <div className="logo-container">
            <RetinaImg
              style={{backgroundColor: AccountType.color, borderRadius: 44}}
              name={AccountType.headerIcon}
              mode={RetinaImg.Mode.ContentPreserve}
              className="logo"
            />
          </div>
          {hideTitle ? <div style={{height: 20}} /> : <h2>{FormComponent.titleLabel(AccountType)}</h2>}
          <FormErrorMessage
            message={errorMessage}
            empty={FormComponent.subtitleLabel(AccountType)}
          />
          { this._renderCredentialsNote() }
          <FormComponent
            ref="form"
            accountInfo={accountInfo}
            errorFieldNames={errorFieldNames}
            submitting={submitting}
            onFieldChange={this.onFieldChange}
            onFieldKeyPress={this.onFieldKeyPress}
            onConnect={this.onConnect}
          />
          <div>
            <div className="btn btn-large btn-gradient" onClick={this.onBack}>Back</div>
            {this._renderButton()}
          </div>
        </div>
      );
    }
  }
}

export default CreatePageForForm;
