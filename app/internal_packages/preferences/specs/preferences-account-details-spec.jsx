import React from 'react';
import { renderIntoDocument } from 'react-dom/test-utils';
import { Account } from 'mailspring-exports';

import PreferencesAccountDetails from '../lib/tabs/preferences-account-details';

const makeComponent = (props = {}) => {
  return renderIntoDocument(<PreferencesAccountDetails {...props} />);
};

const account = new Account({
  id: 1,
  name: 'someone',
  emailAddress: 'someone@nylas.com',
  aliases: [],
  defaultAlias: null,
});

describe('PreferencesAccountDetails', function preferencesAccountDetails() {
  beforeEach(() => {
    this.account = account;
    this.onAccountUpdated = jasmine.createSpy('onAccountUpdated');
    this.component = makeComponent({ account, onAccountUpdated: this.onAccountUpdated });
    spyOn(this.component, 'setState');
  });

  function assertAccountState(actual, expected) {
    for (const key of Object.keys(expected)) {
      expect(actual.account[key]).toEqual(expected[key]);
    }
  }

  describe('_makeAlias', () => {
    it('returns correct alias when empty string provided', () => {
      const alias = this.component._makeAlias('', this.account);
      expect(alias).toEqual('someone <someone@nylas.com>');
    });

    it('returns correct alias when only the name provided', () => {
      const alias = this.component._makeAlias('Chad', this.account);
      expect(alias).toEqual('Chad <someone@nylas.com>');
    });

    it('returns correct alias when email provided', () => {
      const alias = this.component._makeAlias('keith@nylas.com', this.account);
      expect(alias).toEqual('someone <keith@nylas.com>');
    });

    it('returns correct alias if name and email provided', () => {
      const alias = this.component._makeAlias('Donald donald@nylas.com', this.account);
      expect(alias).toEqual('Donald <donald@nylas.com>');
    });

    it('returns correct alias if alias provided', () => {
      const alias = this.component._makeAlias('Donald <donald@nylas.com>', this.account);
      expect(alias).toEqual('Donald <donald@nylas.com>');
    });
  });

  describe('_setState', () => {
    it('sets the correct state', () => {
      this.component._setState({ aliases: ['something'] });
      assertAccountState(this.component.setState.calls[0].args[0], { aliases: ['something'] });
    });
  });

  describe('_onDefaultAliasSelected', () => {
    it('sets the default alias correctly when set to None', () => {
      this.component._onDefaultAliasSelected({ target: { value: 'None' } });
      assertAccountState(this.component.setState.calls[0].args[0], { defaultAlias: null });
    });

    it('sets the default alias correctly when set to any value', () => {
      this.component._onDefaultAliasSelected({ target: { value: 'my alias' } });
      assertAccountState(this.component.setState.calls[0].args[0], { defaultAlias: 'my alias' });
    });
  });

  describe('alias handlers', () => {
    beforeEach(() => {
      this.currentAlias = 'juan <blah@nylas>';
      this.newAlias = 'some <alias@nylas.com>';
      this.account.aliases = [this.currentAlias];
      this.component = makeComponent({
        account: this.account,
        onAccountUpdated: this.onAccountUpdated,
      });
      spyOn(this.component, '_makeAlias').andCallFake(alias => alias);
      spyOn(this.component, 'setState');
    });
    describe('_onAccountAliasCreated', () => {
      it('creates alias correctly', () => {
        this.component._onAccountAliasCreated(this.newAlias);
        assertAccountState(this.component.setState.calls[0].args[0], {
          aliases: [this.currentAlias, this.newAlias],
        });
      });
    });

    describe('_onAccountAliasUpdated', () => {
      it('updates alias correctly when no default alias present', () => {
        this.component._onAccountAliasUpdated(this.newAlias, this.currentAlias, 0);
        assertAccountState(this.component.setState.calls[0].args[0], { aliases: [this.newAlias] });
      });

      it('updates alias correctly when default alias present and it is being updated', () => {
        this.account.defaultAlias = this.currentAlias;
        this.component = makeComponent({
          account: this.account,
          onAccountUpdated: this.onAccountUpdated,
        });
        spyOn(this.component, '_makeAlias').andCallFake(alias => alias);
        spyOn(this.component, 'setState');

        this.component._onAccountAliasUpdated(this.newAlias, this.currentAlias, 0);
        assertAccountState(this.component.setState.calls[0].args[0], {
          aliases: [this.newAlias],
          defaultAlias: this.newAlias,
        });
      });

      it('updates alias correctly when default alias present and it is not being updated', () => {
        this.account.defaultAlias = this.currentAlias;
        this.account.aliases.push('otheralias');
        this.component = makeComponent({
          account: this.account,
          onAccountUpdated: this.onAccountUpdated,
        });
        spyOn(this.component, '_makeAlias').andCallFake(alias => alias);
        spyOn(this.component, 'setState');

        this.component._onAccountAliasUpdated(this.newAlias, 'otheralias', 1);
        assertAccountState(this.component.setState.calls[0].args[0], {
          aliases: [this.currentAlias, this.newAlias],
          defaultAlias: this.currentAlias,
        });
      });
    });

    describe('_onAccountAliasRemoved', () => {
      it('removes alias correctly when no default alias present', () => {
        this.component._onAccountAliasRemoved(this.currentAlias, 0);
        assertAccountState(this.component.setState.calls[0].args[0], { aliases: [] });
      });

      it('removes alias correctly when default alias present and it is being removed', () => {
        this.account.defaultAlias = this.currentAlias;
        this.component = makeComponent({
          account: this.account,
          onAccountUpdated: this.onAccountUpdated,
        });
        spyOn(this.component, '_makeAlias').andCallFake(alias => alias);
        spyOn(this.component, 'setState');

        this.component._onAccountAliasRemoved(this.currentAlias, 0);
        assertAccountState(this.component.setState.calls[0].args[0], {
          aliases: [],
          defaultAlias: null,
        });
      });

      it('removes alias correctly when default alias present and it is not being removed', () => {
        this.account.defaultAlias = this.currentAlias;
        this.account.aliases.push('otheralias');
        this.component = makeComponent({
          account: this.account,
          onAccountUpdated: this.onAccountUpdated,
        });
        spyOn(this.component, '_makeAlias').andCallFake(alias => alias);
        spyOn(this.component, 'setState');

        this.component._onAccountAliasRemoved('otheralias', 1);
        assertAccountState(this.component.setState.calls[0].args[0], {
          aliases: [this.currentAlias],
          defaultAlias: this.currentAlias,
        });
      });
    });
  });
});
