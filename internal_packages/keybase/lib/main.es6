import {PreferencesUIStore, ComponentRegistry, ExtensionRegistry} from 'nylas-exports';

import EncryptMessageButton from './encrypt-button';
import DecryptMessageButton from './decrypt-button';
import DecryptPGPExtension from './decryption-preprocess';
import RecipientKeyChip from './recipient-key-chip';
import PreferencesKeybase from './preferences-keybase';

const PREFERENCE_TAB_ID = 'Encryption'

export function activate() {
  const preferencesTab = new PreferencesUIStore.TabItem({
    tabId: PREFERENCE_TAB_ID,
    displayName: 'Encryption',
    component: PreferencesKeybase,
  });
  ComponentRegistry.register(EncryptMessageButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(DecryptMessageButton, {role: 'message:BodyHeader'});
  ComponentRegistry.register(RecipientKeyChip, {role: 'Composer:RecipientChip'});
  ExtensionRegistry.MessageView.register(DecryptPGPExtension);
  PreferencesUIStore.registerPreferencesTab(preferencesTab);
}

export function deactivate() {
  ComponentRegistry.unregister(EncryptMessageButton);
  ComponentRegistry.unregister(DecryptMessageButton);
  ComponentRegistry.unregister(RecipientKeyChip);
  ExtensionRegistry.MessageView.unregister(DecryptPGPExtension);
  PreferencesUIStore.unregisterPreferencesTab(PREFERENCE_TAB_ID);
}

export function serialize() {
  return {};
}
