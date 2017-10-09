import React from 'react';
import PropTypes from 'prop-types';
import { isValidHost } from './onboarding-helpers';
import CreatePageForForm from './decorators/create-page-for-form';
import FormField from './form-field';

const StandardIMAPPorts = [143, 993];
const StandardSMTPPorts = [25, 465, 587];

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

    if (!account.settings[`imap_username`] || !account.settings[`imap_password`]) {
      return { errorMessage, errorFieldNames, populated: false };
    }

    // Note: we explicitly don't check that an SMTP username / password
    // is provided because occasionally those gateways don't require them!

    for (const type of ['imap', 'smtp']) {
      if (!account.settings[`${type}_host`]) {
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

    const field = `${protocol}_port`;
    const values = protocol === 'imap' ? StandardIMAPPorts : StandardSMTPPorts;
    const isStandard = values.includes(settings[field] / 1);
    const customValue = isStandard ? '0' : settings[field];

    return (
      <span>
        <label htmlFor={`settings.${field}`}>Port:</label>
        <select
          id={`settings.${field}`}
          tabIndex={0}
          value={settings[field]}
          disabled={submitting}
          onKeyPress={onFieldKeyPress}
          onChange={onFieldChange}
        >
          {values.map(v => (
            <option value={v} key={v}>
              {v}
            </option>
          ))}
          <option value={customValue} key="custom">
            Custom
          </option>
        </select>
        {!isStandard && (
          <input
            style={{
              width: 80,
              marginLeft: 6,
              height: 23,
            }}
            id={`settings.${field}`}
            tabIndex={0}
            value={settings[field]}
            disabled={submitting}
            onKeyPress={onFieldKeyPress}
            onChange={onFieldChange}
          />
        )}
      </span>
    );
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
