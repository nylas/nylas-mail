import {mount} from 'enzyme';
import AccountErrorHeader from '../lib/headers/account-error-header';
import {IdentityStore, AccountStore, Account, Actions, React} from 'nylas-exports'
import {ipcRenderer} from 'electron';

describe("AccountErrorHeader", function AccountErrorHeaderTests() {
  describe("when one account is in the `invalid` state", () => {
    beforeEach(() => {
      spyOn(AccountStore, 'accounts').andReturn([
        new Account({id: 'A', syncState: 'invalid', emailAddress: '123@gmail.com'}),
        new Account({id: 'B', syncState: 'running', emailAddress: 'other@gmail.com'}),
      ])
    });

    it("renders an error bar that mentions the account email", () => {
      const header = mount(<AccountErrorHeader />);
      expect(header.find('.notifications-sticky-item')).toBeDefined();
      expect(header.find('.message').text().indexOf('123@gmail.com') > 0).toBe(true);
    });

    it("allows the user to refresh the account", () => {
      const header = mount(<AccountErrorHeader />);
      spyOn(IdentityStore, 'refreshIdentityAndAccounts').andReturn(Promise.resolve());
      header.find('.action.refresh').simulate('click');
      expect(IdentityStore.refreshIdentityAndAccounts).toHaveBeenCalled();
    });

    it("allows the user to reconnect the account", () => {
      const header = mount(<AccountErrorHeader />);
      spyOn(ipcRenderer, 'send');
      header.find('.action.default').simulate('click');
      expect(ipcRenderer.send).toHaveBeenCalledWith('command', 'application:add-account', {
        existingAccount: AccountStore.accounts()[0],
      });
    });
  });

  describe("when more than one account is in the `invalid` state", () => {
    beforeEach(() => {
      spyOn(AccountStore, 'accounts').andReturn([
        new Account({id: 'A', syncState: 'invalid', emailAddress: '123@gmail.com'}),
        new Account({id: 'B', syncState: 'invalid', emailAddress: 'other@gmail.com'}),
      ])
    });

    it("renders an error bar", () => {
      const header = mount(<AccountErrorHeader />);
      expect(header.find('.notifications-sticky-item')).toBeDefined();
    });

    it("allows the user to refresh the accounts", () => {
      const header = mount(<AccountErrorHeader />);
      spyOn(IdentityStore, 'refreshIdentityAndAccounts').andReturn(Promise.resolve());
      header.find('.action.refresh').simulate('click');
      expect(IdentityStore.refreshIdentityAndAccounts).toHaveBeenCalled();
    });

    it("allows the user to open preferences", () => {
      spyOn(Actions, 'switchPreferencesTab')
      spyOn(Actions, 'openPreferences')
      const header = mount(<AccountErrorHeader />);
      header.find('.action.default').simulate('click');
      expect(Actions.openPreferences).toHaveBeenCalled();
      expect(Actions.switchPreferencesTab).toHaveBeenCalledWith('Accounts');
    });
  });

  describe("when all accounts are fine", () => {
    beforeEach(() => {
      spyOn(AccountStore, 'accounts').andReturn([
        new Account({id: 'A', syncState: 'running', emailAddress: '123@gmail.com'}),
        new Account({id: 'B', syncState: 'running', emailAddress: 'other@gmail.com'}),
      ])
    });

    it("renders nothing", () => {
      const header = mount(<AccountErrorHeader />);
      expect(header.html()).toEqual('<span></span>');
    });
  });
});
