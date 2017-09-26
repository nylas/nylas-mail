import { PreferencesUIStore, ExtensionRegistry, ComponentRegistry } from 'mailspring-exports';

import SignatureComposerExtension from './signature-composer-extension';
import SignatureComposerDropdown from './signature-composer-dropdown';

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: 'Signatures',
    displayName: 'Signatures',
    componentClassFn: () => require('./preferences-signatures').default, // eslint-disable-line
  });

  ExtensionRegistry.Composer.register(SignatureComposerExtension);
  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);

  ComponentRegistry.register(SignatureComposerDropdown, {
    role: 'Composer:FromFieldComponents',
  });
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SignatureComposerExtension);
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId);

  ComponentRegistry.unregister(SignatureComposerDropdown);
}

export function serialize() {
  return {};
}
