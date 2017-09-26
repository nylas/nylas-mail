import { React, PropTypes, RegExpUtils } from 'mailspring-exports';
import { isValidHost } from './onboarding-helpers';
import CreatePageForForm from './decorators/create-page-for-form';
import FormField from './form-field';

class AccountExchangeSettingsForm extends React.Component {
  static displayName = 'AccountExchangeSettingsForm';

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
    return 'Add your Exchange account';
  };

  static subtitleLabel = () => {
    return 'Enter your Exchange credentials to get started.';
  };

  static validateAccount = account => {
    const { emailAddress, password, name } = account;
    const errorFieldNames = [];
    let errorMessage = null;

    if (!emailAddress || !password || !name) {
      return { errorMessage, errorFieldNames, populated: false };
    }

    if (!RegExpUtils.emailRegex().test(emailAddress)) {
      errorFieldNames.push('email');
      errorMessage = 'Please provide a valid email address.';
    }
    if (!account.settings.password) {
      errorFieldNames.push('password');
      errorMessage = 'Please provide a password for your account.';
    }
    if (!account.name) {
      errorFieldNames.push('name');
      errorMessage = 'Please provide your name.';
    }
    if (account.settings.eas_server_host && !isValidHost(account.settings.eas_server_host)) {
      errorFieldNames.push('eas_server_host');
      errorMessage = 'Please provide a valid host name.';
    }

    return { errorMessage, errorFieldNames, populated: true };
  };

  constructor(props) {
    super(props);
    this.state = { showAdvanced: false };
  }

  submit() {
    this.props.onConnect();
  }

  render() {
    const { errorFieldNames, account } = this.props;
    const showAdvanced =
      this.state.showAdvanced ||
      errorFieldNames.includes('eas_server_host') ||
      errorFieldNames.includes('username') ||
      account.eas_server_host ||
      account.username;

    let classnames = 'twocol';
    if (!showAdvanced) {
      classnames += ' hide-second-column';
    }

    return (
      <div className={classnames}>
        <div className="col">
          <FormField field="name" title="Name" {...this.props} />
          <FormField field="email" title="Email" {...this.props} />
          <FormField field="password" title="Password" type="password" {...this.props} />
          <a
            className="toggle-advanced"
            onClick={() => this.setState({ showAdvanced: !this.state.showAdvanced })}
          >
            {showAdvanced ? 'Hide Advanced Options' : 'Show Advanced Options'}
          </a>
        </div>
        <div className="col">
          <FormField field="username" title="Username (Optional)" {...this.props} />
          <FormField field="eas_server_host" title="Exchange Server (Optional)" {...this.props} />
        </div>
      </div>
    );
  }
}

export default CreatePageForForm(AccountExchangeSettingsForm);
