import { ExtensionRegistry } from 'nylas-exports';
import SpellcheckComposerExtension from './spellcheck-composer-extension';

export function activate() {
  if (AppEnv.config.get('core.composing.spellcheck')) {
    ExtensionRegistry.Composer.register(SpellcheckComposerExtension);
  }
}

export function deactivate() {
  if (AppEnv.config.get('core.composing.spellcheck')) {
    ExtensionRegistry.Composer.unregister(SpellcheckComposerExtension);
  }
}
