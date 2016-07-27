import {ExtensionRegistry} from 'nylas-exports';
import SpellcheckComposerExtension from './spellcheck-composer-extension';

export function activate() {
  if (NylasEnv.config.get("core.composing.spellcheck")) {
    ExtensionRegistry.Composer.register(SpellcheckComposerExtension);
  }
}

export function deactivate() {
  if (NylasEnv.config.get("core.composing.spellcheck")) {
    ExtensionRegistry.Composer.unregister(SpellcheckComposerExtension);
  }
}
