import { shell } from 'electron';
import { RetinaImg } from 'nylas-component-kit';
import { NylasAPIRequest, Actions, React, ReactDOM, PropTypes } from 'nylas-exports';

import OnboardingActions from '../onboarding-actions';
import { finalizeAndValidateAccount } from '../onboarding-helpers';
import FormErrorMessage from '../form-error-message';
import AccountProviders from '../account-providers';

const CreatePageForForm = FormComponent => {
  return class Composed extends React.Component {
    static displayName = FormComponent.displayName;

    static propTypes = {
      account: PropTypes.object,
    };

    constructor(props) {
      super(props);

      this.state = Object.assign(
        {
          account: this.props.account.clone(),
          errorFieldNames: [],
          errorMessage: null,
        },
        FormComponent.validateAccount(this.props.account)
      );
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

    _isValid() {
      const { populated, errorFieldNames } = this.state;
      return errorFieldNames.length === 0 && populated;
    }

    onFieldChange = event => {
      const next = this.state.account.clone();

      let val = event.target.value;
      if (event.target.type === 'checkbox') {
        val = event.target.checked;
      }
      if (event.target.id === 'emailAddress') {
        val = val.trim();
      }

      if (event.target.id.includes('.')) {
        const [parent, key] = event.target.id.split('.');
        next[parent][key] = val;
      } else {
        next[event.target.id] = val;
      }

      const { errorFieldNames, errorMessage, populated } = FormComponent.validateAccount(next);

      this.setState({
        account: next,
        errorFieldNames,
        errorMessage,
        populated,
        errorStatusCode: null,
      });
    };

    onSubmit = () => {
      OnboardingActions.setAccount(this.state.account);
      this._formEl.submit();
    };

    onFieldKeyPress = event => {
      if (!this._isValid()) {
        return;
      }
      if (['Enter', 'Return'].includes(event.key)) {
        this.onSubmit();
      }
    };

    onBack = () => {
      OnboardingActions.setAccount(this.state.account);
      OnboardingActions.moveToPreviousPage();
    };

    onConnect = updatedAccount => {
      const account = updatedAccount || this.state.account;

      this.setState({ submitting: true });

      finalizeAndValidateAccount(account)
        .then(validated => {
          OnboardingActions.moveToPage('account-onboarding-success');
          OnboardingActions.finishAndAddAccount(validated);
        })
        .catch(err => {
          Actions.recordUserEvent('Email Account Auth Failed', {
            errorMessage: err.message,
            provider: account.provider,
          });

          const errorFieldNames = err.body
            ? err.body.missing_fields || err.body.missing_settings || []
            : [];
          let errorMessage = err.message;
          const errorStatusCode = err.statusCode;

          if (err.errorType === 'setting_update_error') {
            errorMessage =
              'The IMAP/SMTP servers for this account do not match our records. Please verify that any server names you entered are correct. If your IMAP/SMTP server has changed, first remove this account from Mailspring, then try logging in again.';
          }
          if (
            err.errorType &&
            err.errorType.includes('autodiscover') &&
            account.provider === 'exchange'
          ) {
            errorFieldNames.push('eas_server_host');
            errorFieldNames.push('username');
          }
          if (err.statusCode === 401) {
            if (/smtp/i.test(err.message)) {
              errorFieldNames.push('smtp_username');
              errorFieldNames.push('smtp_password');
            }
            if (/imap/i.test(err.message)) {
              errorFieldNames.push('imap_username');
              errorFieldNames.push('imap_password');
            }
            // not sure what these are for -- backcompat?
            errorFieldNames.push('password');
            errorFieldNames.push('email');
            errorFieldNames.push('username');
          }
          if (NylasAPIRequest.TimeoutErrorCodes.includes(err.statusCode)) {
            // timeout
            errorMessage = 'We were unable to reach your mail provider. Please try again.';
          }

          this.setState({ errorMessage, errorStatusCode, errorFieldNames, submitting: false });
        });
    };

    _renderButton() {
      const { account, submitting } = this.state;
      const buttonLabel = FormComponent.submitLabel(account);

      // We're not on the last page.
      if (submitting) {
        return (
          <button className="btn btn-large btn-disabled btn-add-account spinning">
            <RetinaImg
              name="sending-spinner.gif"
              width={15}
              height={15}
              mode={RetinaImg.Mode.ContentPreserve}
            />
            Adding account&hellip;
          </button>
        );
      }

      if (!this._isValid()) {
        return (
          <button className="btn btn-large btn-gradient btn-disabled btn-add-account">
            {buttonLabel}
          </button>
        );
      }

      return (
        <button className="btn btn-large btn-gradient btn-add-account" onClick={this.onSubmit}>
          {buttonLabel}
        </button>
      );
    }

    // When a user enters the wrong credentials, show a message that could
    // help with common problems. For instance, they may need an app password,
    // or to enable specific settings with their provider.
    _renderCredentialsNote() {
      const { errorStatusCode, account } = this.state;
      if (errorStatusCode !== 401) {
        return false;
      }
      let message;
      let articleURL;
      if (account.emailAddress.includes('@yahoo.com')) {
        message = 'Have you enabled access through Yahoo?';
        articleURL = 'https://support.getmailspring.com/hc/en-us/articles/115001076128';
      } else {
        message = 'Some providers require an app password.';
        articleURL = 'https://support.getmailspring.com/hc/en-us/articles/115001056608';
      }
      // We don't use a FormErrorMessage component because the content
      // we need to display has HTML.
      return (
        <div className="message error">
          {message}&nbsp;
          <a
            href=""
            style={{ cursor: 'pointer' }}
            onClick={() => {
              shell.openExternal(articleURL);
            }}
          >
            Learn more.
          </a>
        </div>
      );
    }

    render() {
      const { account, errorMessage, errorFieldNames, submitting } = this.state;
      const providerConfig = AccountProviders.find(({ provider }) => provider === account.provider);

      if (!providerConfig) {
        throw new Error(`Cannot find account provider ${account.provider}`);
      }

      const hideTitle = errorMessage && errorMessage.length > 120;

      return (
        <div className={`page account-setup ${FormComponent.displayName}`}>
          <div className="logo-container">
            <RetinaImg
              style={{ backgroundColor: providerConfig.color, borderRadius: 44 }}
              name={providerConfig.headerIcon}
              mode={RetinaImg.Mode.ContentPreserve}
              className="logo"
            />
          </div>
          {hideTitle ? (
            <div style={{ height: 20 }} />
          ) : (
            <h2>{FormComponent.titleLabel(providerConfig)}</h2>
          )}
          <FormErrorMessage
            message={errorMessage}
            empty={FormComponent.subtitleLabel(providerConfig)}
          />
          {this._renderCredentialsNote()}
          <FormComponent
            ref={el => {
              this._formEl = el;
            }}
            account={account}
            errorFieldNames={errorFieldNames}
            submitting={submitting}
            onFieldChange={this.onFieldChange}
            onFieldKeyPress={this.onFieldKeyPress}
            onConnect={this.onConnect}
          />
          <div>
            <div className="btn btn-large btn-gradient" onClick={this.onBack}>
              Back
            </div>
            {this._renderButton()}
          </div>
        </div>
      );
    }
  };
};

export default CreatePageForForm;
