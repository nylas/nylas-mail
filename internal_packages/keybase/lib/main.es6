import {PreferencesUIStore, ComponentRegistry, ExtensionRegistry} from 'nylas-exports';

import EncryptMessageButton from './encrypt-button';
import DecryptMessageButton from './decrypt-button';
import DecryptPGPExtension from './decryption-preprocess';
import RecipientKeyChip from './recipient-key-chip';

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: 'PGP Encryption',
    displayName: 'PGP Encryption',
    component: require('./preferences-keybase'),
  });
  ComponentRegistry.register(EncryptMessageButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(DecryptMessageButton, {role: 'message:BodyHeader'});
  ComponentRegistry.register(RecipientKeyChip, {role: 'Composer:RecipientChip'});
  ExtensionRegistry.MessageView.register(DecryptPGPExtension);
  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
}

export function deactivate() {
  ComponentRegistry.unregister(EncryptMessageButton);
  ComponentRegistry.unregister(DecryptMessageButton);
  ComponentRegistry.unregister(RecipientKeyChip);
  ExtensionRegistry.MessageView.unregister(DecryptPGPExtension);
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.tabId);
}

export function serialize() {
  return {};
}
