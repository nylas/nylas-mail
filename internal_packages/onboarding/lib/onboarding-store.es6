import {AccountStore, Actions, IdentityStore, NylasSyncStatusStore} from 'nylas-exports';
import {ipcRenderer} from 'electron';
import NylasStore from 'nylas-store';

import OnboardingActions from './onboarding-actions';

function accountTypeForProvider(provider) {
  if (provider === 'eas') {
    return 'exchange';
  }
  if (provider === 'custom') {
    return 'imap';
  }
  return provider;
}

class OnboardingStore extends NylasStore {
  constructor() {
    super();

    NylasEnv.config.onDidChange('env', this._onEnvChanged);
    this._onEnvChanged();

    this.listenTo(OnboardingActions.moveToPreviousPage, this._onMoveToPreviousPage)
    this.listenTo(OnboardingActions.moveToPage, this._onMoveToPage)
    this.listenTo(OnboardingActions.accountJSONReceived, this._onAccountJSONReceived)
    this.listenTo(OnboardingActions.authenticationJSONReceived, this._onAuthenticationJSONReceived)
    this.listenTo(OnboardingActions.setAccountInfo, this._onSetAccountInfo);
    this.listenTo(OnboardingActions.setAccountType, this._onSetAccountType);

    const {existingAccount, addingAccount, accountType} = NylasEnv.getWindowProps();

    const hasAccounts = (AccountStore.accounts().length > 0)
    const identity = IdentityStore.identity();

    if (identity) {
      this._accountInfo = {
        name: `${identity.firstname || ""} ${identity.lastname || ""}`,
      };
    } else {
      this._accountInfo = {};
    }

    if (existingAccount) {
      // Used when re-adding an account after re-connecting
      const existingAccountType = accountTypeForProvider(existingAccount.provider);
      this._pageStack = ['account-choose']
      this._accountInfo = {
        name: existingAccount.name,
        email: existingAccount.emailAddress,
      };
      this._onSetAccountType(existingAccountType);
    } else if (addingAccount) {
      // Adding a new, unknown account
      this._pageStack = ['account-choose'];
      if (accountType) {
        this._onSetAccountType(accountType);
      }
    } else if (identity) {
      // Should only happen if config was edited to remove all accounts,
      // but don't want to re-login to Nylas account. Very useful when
      // switching environments.
      this._pageStack = ['account-choose'];
    } else if (hasAccounts) {
      // Should only happen when the user has "signed out" of their Nylas ID,
      // but already has accounts synced. Or is upgrading from a very old build.
      // We used to show "Welcome Back", but now just jump to sign in.
      this._pageStack = ['authenticate'];
    } else {
      // Standard new user onboarding flow.
      this._pageStack = ['welcome'];
    }
  }

  _onEnvChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.welcomeRoot = "http://0.0.0.0:5555";
    } else if (env === 'experimental') {
      this.welcomeRoot = "https://www-experimental.nylas.com";
    } else if (env === 'staging') {
      this.welcomeRoot = "https://www-staging.nylas.com";
    } else {
      this.welcomeRoot = "https://nylas.com";
    }
  }

  _onOnboardingComplete = () => {
    // When account JSON is received, we want to notify external services
    // that it succeeded. Unfortunately in this case we're likely to
    // close the window before those requests can be made. We add a short
    // delay here to ensure that any pending requests have a chance to
    // clear before the window closes.
    setTimeout(() => {
      ipcRenderer.send('account-setup-successful');
    }, 100);
  }

  _onSetAccountType = (type) => {
    let nextPage = "account-settings";
    if (type === 'gmail') {
      nextPage = "account-settings-gmail";
    } else if (type === 'exchange') {
      nextPage = "account-settings-exchange";
    }

    Actions.recordUserEvent('Selected Account Type', {
      provider: type,
    });

    // Don't carry over any type-specific account information
    const {email, name, password} = this._accountInfo;
    this._onSetAccountInfo({email, name, password, type});
    this._onMoveToPage(nextPage);
  }

  _onSetAccountInfo = (info) => {
    this._accountInfo = info;
    this.trigger();
  }

  _onMoveToPreviousPage = () => {
    this._pageStack.pop();
    this.trigger();
  }

  _onMoveToPage = (page) => {
    this._pageStack.push(page)
    this.trigger();
  }

  _onAuthenticationJSONReceived = (json) => {
    const isFirstAccount = AccountStore.accounts().length === 0;

    Actions.setNylasIdentity(json);

    setTimeout(() => {
      if (isFirstAccount) {
        this._onSetAccountInfo(Object.assign({}, this._accountInfo, {
          name: `${json.firstname || ""} ${json.lastname || ""}`,
          email: json.email,
        }));
        OnboardingActions.moveToPage('account-choose');
      } else {
        this._onOnboardingComplete();
      }
    }, 1000);
  }

  _onAccountJSONReceived = async (json, localToken, cloudToken) => {
    try {
      const isFirstAccount = AccountStore.accounts().length === 0;

      AccountStore.addAccountFromJSON(json, localToken, cloudToken);
      this._accountFromAuth = AccountStore.accountForEmail(json.email_address);

      Actions.recordUserEvent('Email Account Auth Succeeded', {
        provider: this._accountFromAuth.provider,
      });
      ipcRenderer.send('new-account-added');
      NylasEnv.displayWindow();

      if (isFirstAccount) {
        this._onMoveToPage('initial-preferences');
        Actions.recordUserEvent('First Account Linked', {
          provider: this._accountFromAuth.provider,
        });
      } else {
        await NylasSyncStatusStore.whenCategoryListSynced(json.id)
        this._onOnboardingComplete();
      }
    } catch (e) {
      NylasEnv.reportError(e);
      NylasEnv.showErrorDialog("Unable to Connect Account", "Sorry, something went wrong on the Nylas server. Please try again. If you're still having issues, contact us at support@nylas.com.");
    }
  }

  page() {
    return this._pageStack[this._pageStack.length - 1];
  }

  pageDepth() {
    return this._pageStack.length;
  }

  accountInfo() {
    return this._accountInfo;
  }

  accountFromAuth() {
    return this._accountFromAuth;
  }
}

export default new OnboardingStore();
