import {AccountStore, Actions, IdentityStore} from 'nylas-exports';
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

    this.listenTo(OnboardingActions.moveToPreviousPage, this._onMoveToPreviousPage)
    this.listenTo(OnboardingActions.moveToPage, this._onMoveToPage)
    this.listenTo(OnboardingActions.accountJSONReceived, this._onAccountJSONReceived)
    this.listenTo(OnboardingActions.identityJSONReceived, this._onIdentityJSONReceived)
    this.listenTo(OnboardingActions.setAccountInfo, this._onSetAccountInfo);
    this.listenTo(OnboardingActions.setAccountType, this._onSetAccountType);
    ipcRenderer.on('set-account-type', (e, type) => {
      if (type) {
        this._onSetAccountType(type)
      } else {
        this._pageStack = ['account-choose']
        this.trigger()
      }
    })

    const {existingAccount, addingAccount, accountType} = NylasEnv.getWindowProps();

    const hasAccounts = (AccountStore.accounts().length > 0)
    const identity = IdentityStore.identity();

    if (identity) {
      this._accountInfo = {
        name: `${identity.firstName || ""} ${identity.lastName || ""}`,
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

  _onIdentityJSONReceived = async (json) => {
    const isFirstAccount = AccountStore.accounts().length === 0;

    await IdentityStore.saveIdentity(json);

    setTimeout(() => {
      if (isFirstAccount) {
        this._onSetAccountInfo(Object.assign({}, this._accountInfo, {
          name: `${json.firstName || ""} ${json.lastName || ""}`,
          email: json.emailAddress,
        }));
        OnboardingActions.moveToPage('account-choose');
      } else {
        this._onOnboardingComplete();
      }
    }, 1000);
  }

  _onAccountJSONReceived = async (json) => {
    try {
      const isFirstAccount = AccountStore.accounts().length === 0;
      AccountStore.addAccountFromJSON(json);

      Actions.recordUserEvent('Email Account Auth Succeeded', {
        provider: json.provider,
      });

      ipcRenderer.send('new-account-added');
      NylasEnv.displayWindow();

      if (isFirstAccount) {
        this._onMoveToPage('initial-preferences');
        Actions.recordUserEvent('First Account Linked', {
          provider: json.provider,
        });
      } else {
        // let them see the "success" screen for a moment
        // before the window is closed.
        setTimeout(() => {
          this._onOnboardingComplete();
        }, 2000);
      }
    } catch (e) {
      NylasEnv.reportError(e);
      NylasEnv.showErrorDialog("Unable to Connect Account", "Sorry, something went wrong on the Nylas server. Please try again. If you're still having issues, contact us at support@getmailspring.com.");
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
}

export default new OnboardingStore();
