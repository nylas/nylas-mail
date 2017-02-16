import {PreferencesUIStore, ExtensionRegistry, SignatureStore, ComponentRegistry} from 'nylas-exports';

import SignatureComposerExtension from './signature-composer-extension';
import SignatureComposerDropdown from './signature-composer-dropdown';
import PreferencesSignatures from "./preferences-signatures";

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: "Signatures",
    displayName: "Signatures",
    component: PreferencesSignatures,
  });

  ExtensionRegistry.Composer.register(SignatureComposerExtension);
  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);
  SignatureStore.activate();

  ComponentRegistry.register(SignatureComposerDropdown, {
    role: 'Composer:FromFieldComponents',
  });
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SignatureComposerExtension);
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId);
  SignatureStore.deactivate();

  ComponentRegistry.unregister(SignatureComposerDropdown);
}

export function serialize() {
  return {};
}
