import {PreferencesUIStore, ExtensionRegistry} from 'nylas-exports';

import SignatureComposerExtension from './signature-composer-extension';
import SignatureStore from './signature-store';
import PreferencesSignatures from "./preferences-signatures";

export function activate() {
  this.preferencesTab = new PreferencesUIStore.TabItem({
    tabId: "Signatures",
    displayName: "Signatures",
    component: PreferencesSignatures,
  });

  ExtensionRegistry.Composer.register(SignatureComposerExtension);
  PreferencesUIStore.registerPreferencesTab(this.preferencesTab);

  this.signatureStore = new SignatureStore();
  this.signatureStore.activate();
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SignatureComposerExtension);
  PreferencesUIStore.unregisterPreferencesTab(this.preferencesTab.sectionId);
  this.signatureStore.deactivate();
}

export function serialize() {
  return {};
}
