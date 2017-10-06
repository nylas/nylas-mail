import React from 'react';
import PropTypes from 'prop-types';
import { isValidHost } from './onboarding-helpers';
import CreatePageForForm from './decorators/create-page-for-form';
import FormField from './form-field';

class AccountIMAPSettingsForm extends React.Component {
  static displayName = 'AccountIMAPSettingsForm';

  static propTypes = {
    account: PropTypes.object,
    errorFieldNames: PropTypes.array,
    submitting: PropTypes.bool,
    onConnect: PropTypes.func,
    onFieldChange: PropTypes.func,
    onFieldKeyPress: PropTypes.func,
  };

  static submitLabel = () => {
    return 'Connect Account';
  };

  static titleLabel = () => {
    return 'Set up your account';
  };

  static subtitleLabel = () => {
    return 'Complete the IMAP and SMTP settings below to connect your account.';
  };

  static validateAccount = account => {
    let errorMessage = null;
    const errorFieldNames = [];

    for (const type of ['imap', 'smtp']) {
      if (
        !account.settings[`${type}_host`] ||
        !account.settings[`${type}_username`] ||
        !account.settings[`${type}_password`]
      ) {
        return { errorMessage, errorFieldNames, populated: false };
      }
      if (!isValidHost(account.settings[`${type}_host`])) {
        errorMessage = 'Please provide a valid hostname or IP adddress.';
        errorFieldNames.push(`${type}_host`);
      }
      if (!Number.isInteger(account.settings[`${type}_port`] / 1)) {
        errorMessage = 'Please provide a valid port number.';
        errorFieldNames.push(`${type}_port`);
      }
    }

    return { errorMessage, errorFieldNames, populated: true };
  };

  submit() {
    const { settings } = this.props.account;
    if (settings.imap_host && settings.imap_host.includes('imap.gmail.com')) {
      AppEnv.showErrorDialog({
        title: 'Are you sure?',
        message:
          `This looks like a Gmail account! While it's possible to setup an App ` +
          `Password and connect to Gmail via IMAP, Mailspring also supports Google OAuth. Go ` +
          `back and select "Gmail & Google Apps" from the provider screen.`,
      });
    }
    this.props.onConnect();
  }

  renderPortDropdown(protocol) {
    if (!['imap', 'smtp'].includes(protocol)) {
      throw new Error(`Can't render port dropdown for protocol '${protocol}'`);
    }
    const { account: { settings }, submitting, onFieldKeyPress, onFieldChange } = this.props;

    if (protocol === 'imap') {
      return (
        <span>
          <label htmlFor="settings.imap_port">Port:</label>
          <select
            id="settings.imap_port"
            tabIndex={0}
            value={settings.imap_port}
            disabled={submitting}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          >
            <option value="143" key="143">
              143
            </option>
            <option value="993" key="993">
              993
            </option>
          </select>
        </span>
      );
    }
    if (protocol === 'smtp') {
      return (
        <span>
          <label htmlFor="settings.smtp_port">Port:</label>
          <select
            id="settings.smtp_port"
            tabIndex={0}
            value={settings.smtp_port}
            disabled={submitting}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          >
            <option value="25" key="25">
              25
            </option>
            <option value="465" key="465">
              465
            </option>
            <option value="587" key="587">
              587
            </option>
          </select>
        </span>
      );
    }
    return '';
  }

  renderSecurityDropdown(protocol) {
    const { account: { settings }, submitting, onFieldKeyPress, onFieldChange } = this.props;

    return (
      <div>
        <span>
          <label htmlFor={`settings.${protocol}_security`}>Security:</label>
          <select
            id={`settings.${protocol}_security`}
            tabIndex={0}
            value={settings[`${protocol}_security`]}
            disabled={submitting}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          >
            <option value="SSL / TLS" key="SSL">
              SSL / TLS
            </option>
            <option value="STARTTLS" key="STARTTLS">
              STARTTLS
            </option>
            <option value="none" key="none">
              None
            </option>
          </select>
        </span>
        <span style={{ paddingLeft: '20px', paddingTop: '10px' }}>
          <input
            type="checkbox"
            id={`settings.${protocol}_allow_insecure_ssl`}
            disabled={submitting}
            checked={settings[`${protocol}_allow_insecure_ssl`] || false}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          />
          <label htmlFor={`${protocol}_allow_insecure_ssl"`} className="checkbox">
            Allow insecure SSL
          </label>
        </span>
      </div>
    );
  }

  renderFieldsForType(type) {
    return (
      <div>
        <FormField field={`settings.${type}_host`} title={'Server'} {...this.props} />
        <div style={{ textAlign: 'left' }}>
          {this.renderPortDropdown(type)}
          {this.renderSecurityDropdown(type)}
        </div>
        <FormField field={`settings.${type}_username`} title={'Username'} {...this.props} />
        <FormField
          field={`settings.${type}_password`}
          title={'Password'}
          type="password"
          {...this.props}
        />
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
    );
  }
}

export default CreatePageForForm(AccountIMAPSettingsForm);
