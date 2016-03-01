import {ExtensionRegistry} from 'nylas-exports';
import SpellcheckComposerExtension from './spellcheck-composer-extension';

export function activate() {
  ExtensionRegistry.Composer.register(SpellcheckComposerExtension);
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SpellcheckComposerExtension);
}
