import { mount } from 'enzyme';
import { React, AccountStore, Account, Actions, MailRulesStore } from 'mailspring-exports';
import DisabledMailRulesNotification from '../lib/items/disabled-mail-rules-notif';

describe('DisabledMailRulesNotification', function DisabledMailRulesNotifTests() {
  beforeEach(() => {
    spyOn(AccountStore, 'accounts').andReturn([
      new Account({ id: 'A', syncState: Account.SYNC_STATE_OK, emailAddress: '123@gmail.com' }),
    ]);
  });
  describe('When there is one disabled mail rule', () => {
    beforeEach(() => {
      spyOn(MailRulesStore, 'disabledRules').andReturn([{ accountId: 'A' }]);
      this.notif = mount(<DisabledMailRulesNotification />);
    });
    it('displays a notification', () => {
      expect(this.notif.find('.notification').exists()).toEqual(true);
    });

    it('allows users to open the preferences', () => {
      spyOn(Actions, 'switchPreferencesTab');
      spyOn(Actions, 'openPreferences');
      this.notif.find('#action-0').simulate('click');
      expect(Actions.switchPreferencesTab).toHaveBeenCalledWith('Mail Rules', { accountId: 'A' });
      expect(Actions.openPreferences).toHaveBeenCalled();
    });
  });

  describe('When there are multiple disabled mail rules', () => {
    beforeEach(() => {
      spyOn(MailRulesStore, 'disabledRules').andReturn([{ accountId: 'A' }, { accountId: 'A' }]);
      this.notif = mount(<DisabledMailRulesNotification />);
    });
    it('displays a notification', () => {
      expect(this.notif.find('.notification').exists()).toEqual(true);
    });

    it('allows users to open the preferences', () => {
      spyOn(Actions, 'switchPreferencesTab');
      spyOn(Actions, 'openPreferences');
      this.notif.find('#action-0').simulate('click');
      expect(Actions.switchPreferencesTab).toHaveBeenCalledWith('Mail Rules', { accountId: 'A' });
      expect(Actions.openPreferences).toHaveBeenCalled();
    });
  });

  describe('When there are no disabled mail rules', () => {
    beforeEach(() => {
      spyOn(MailRulesStore, 'disabledRules').andReturn([]);
      this.notif = mount(<DisabledMailRulesNotification />);
    });
    it('does not display a notification', () => {
      expect(this.notif.find('.notification').exists()).toEqual(false);
    });
  });
});
